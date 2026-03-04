import { TriggerEvent, logger } from "@trigger.dev/sdk";
import { client } from "@trigger.dev/sdk";
import { createClient } from "@supabase/supabase-js";
import axios from "axios";

const supabase = createClient(
  process.env.SUPABASE_URL || "",
  process.env.SUPABASE_ANON_KEY || ""
);

interface ServiceRequest {
  id: string;
  location: { type: string; coordinates: [number, number] };
  category_id: string;
  matching_radius_miles: number;
  customer_id: string;
  title: string;
  address_city: string;
  address_state: string;
  budget_min: number;
  budget_max: number;
}

interface MatchedProvider {
  provider_id: string;
  business_name: string;
  tier: "standard" | "preferred" | "elite";
  composite_rating: number;
  completion_rate: number;
  distance_miles: number;
  available_capacity: number;
  composite_score: number;
  email: string;
  phone: string;
  fcm_token?: string;
  notification_preferences: Record<string, boolean>;
}

/**
 * Matching Engine Job
 * Triggered when a new service request is created
 * Performs spatial search, scoring, ranking, and notification dispatch
 */
export const matchingEngine = client.defineJob({
  id: "matching-engine",
  name: "Service Request Matching Engine",
  version: "1.0.0",
  trigger: {
    events: ["service_request.created"],
  },
  run: async (event: ServiceRequest, { io, ctx }: any) => {
    logger.info(`Matching engine triggered for request: ${event.id}`);

    // Step 1: Get request details
    const { data: request, error: requestError } = await supabase
      .from("service_requests")
      .select("*")
      .eq("id", event.id)
      .single();

    if (requestError || !request) {
      logger.error(`Failed to fetch request: ${requestError?.message}`);
      return { success: false, error: "Request not found" };
    }

    // Step 2: Perform spatial query to find nearby providers
    logger.info(
      `Searching for providers within ${request.matching_radius_miles} miles`
    );

    const { data: candidates, error: spatialError } = await io.runStep(
      "spatial-query",
      async () => {
        return await supabase.rpc("find_nearby_providers", {
          request_longitude: request.location.coordinates[0],
          request_latitude: request.location.coordinates[1],
          category_id: request.category_id,
          radius_miles: request.matching_radius_miles,
        });
      }
    );

    if (spatialError || !candidates || candidates.length === 0) {
      logger.warn(`No providers found in initial radius search`);

      // Expand radius and try again
      return await io.runStep("expand-and-retry", async () => {
        const expandedRadius = request.matching_radius_miles + 10;
        logger.info(`Expanding search radius to ${expandedRadius} miles`);

        const { data: expandedCandidates, error: expandError } =
          await supabase.rpc("find_nearby_providers", {
            request_longitude: request.location.coordinates[0],
            request_latitude: request.location.coordinates[1],
            category_id: request.category_id,
            radius_miles: expandedRadius,
          });

        if (expandError || !expandedCandidates || expandedCandidates.length === 0) {
          logger.warn(`No providers found even after expanding radius`);
          // Notify customer that no providers available
          await notifyCustomerNoProviders(request);
          return { success: false, error: "No providers available" };
        }

        return {
          success: true,
          providers: expandedCandidates,
          radiusExpanded: true,
        };
      });
    }

    logger.info(`Found ${candidates.length} candidate providers`);

    // Step 3: Rank providers by composite score (already done in find_nearby_providers)
    const rankedProviders = (candidates as MatchedProvider[])
      .sort((a, b) => b.composite_score - a.composite_score)
      .slice(0, 10); // Top 10

    logger.info(`Selected ${rankedProviders.length} providers for notifications`);

    // Step 4: Insert matched_providers records
    await io.runStep("insert-matched-providers", async () => {
      const matchRecords = rankedProviders.map((provider, index) => ({
        request_id: request.id,
        provider_id: provider.provider_id,
        composite_score: provider.composite_score,
        distance_miles: provider.distance_miles,
        notified_at: new Date().toISOString(),
        notification_channels: { email: true, push: true, sms: true },
      }));

      const { error: insertError } = await supabase
        .from("matched_providers")
        .insert(matchRecords);

      if (insertError) {
        logger.error(`Failed to insert matched providers: ${insertError.message}`);
        throw insertError;
      }

      logger.info(`Inserted ${matchRecords.length} matched provider records`);
      return matchRecords.length;
    });

    // Step 5: Send notifications to providers
    const notificationResults = await io.runStep(
      "send-provider-notifications",
      async () => {
        const results = [];

        for (const [index, provider] of rankedProviders.entries()) {
          try {
            // Check provider preferences
            const prefs = provider.notification_preferences || {
              email: true,
              sms: true,
              push: true,
            };

            const notificationData = {
              match_rank: index + 1,
              total_matches: rankedProviders.length,
              request_id: request.id,
              distance_miles: provider.distance_miles.toFixed(1),
              title: request.title,
              city: request.address_city,
              state: request.address_state,
              budget_min: request.budget_min,
              budget_max: request.budget_max,
            };

            // Send email
            if (prefs.email) {
              await sendEmailNotification(
                provider,
                request,
                index + 1,
                rankedProviders.length
              );
            }

            // Send push if FCM token available
            if (prefs.push && provider.fcm_token) {
              await sendPushNotification(
                provider.fcm_token,
                request.title,
                request.address_city
              );
            }

            // Send SMS if phone available
            if (prefs.sms && provider.phone) {
              await sendSMSNotification(
                provider.phone,
                request.title,
                request.address_city,
                provider.distance_miles.toFixed(1)
              );
            }

            results.push({
              provider_id: provider.provider_id,
              success: true,
            });
          } catch (error: any) {
            logger.error(
              `Failed to notify provider ${provider.provider_id}: ${error.message}`
            );
            results.push({
              provider_id: provider.provider_id,
              success: false,
              error: error.message,
            });
          }
        }

        return results;
      }
    );

    // Step 6: Update request status to "bidding" and set bid_window_end
    const bidWindowEndTime = new Date(Date.now() + 30 * 60 * 1000); // 30 minutes

    await io.runStep("update-request-status", async () => {
      const { error: updateError } = await supabase
        .from("service_requests")
        .update({
          status: "bidding",
          bid_window_end: bidWindowEndTime.toISOString(),
        })
        .eq("id", request.id);

      if (updateError) {
        logger.error(`Failed to update request status: ${updateError.message}`);
        throw updateError;
      }

      logger.info(
        `Request ${request.id} moved to bidding status. Window ends at ${bidWindowEndTime.toISOString()}`
      );
    });

    // Step 7: Notify customer that matching is complete
    await io.runStep("notify-customer", async () => {
      const { error: notifError } = await supabase
        .from("notifications")
        .insert({
          user_id: request.customer_id,
          user_role: "customer",
          type: "bids_incoming",
          title: "Bids Coming In!",
          body: `Your request for ${request.title} has been sent to ${rankedProviders.length} verified providers.`,
          data: {
            request_id: request.id,
            matched_provider_count: rankedProviders.length,
          },
        });

      if (notifError) {
        logger.warn(
          `Failed to notify customer: ${notifError.message}. Continuing anyway.`
        );
      }
    });

    // Step 8: Schedule bid window close check (5 min before deadline)
    const checkTime = new Date(bidWindowEndTime.getTime() - 5 * 60 * 1000);

    await io.scheduleJob(
      `bid-window-check-${request.id}`,
      {
        trigger: {
          type: "scheduled",
          timestamp: checkTime,
        },
      },
      async () => {
        logger.info(`Checking bids for request ${request.id}`);
        await checkBidWindowAndExpand(request);
      }
    );

    logger.info(`Matching engine completed for request ${request.id}`);

    return {
      success: true,
      request_id: request.id,
      matched_providers_count: rankedProviders.length,
      bid_window_end: bidWindowEndTime.toISOString(),
      notification_results: notificationResults,
    };
  },
});

/**
 * Scheduled job to check if bids were received
 * If not, expand radius and re-notify providers
 */
async function checkBidWindowAndExpand(request: ServiceRequest) {
  logger.info(`Bid window check for request ${request.id}`);

  // Get current bid count
  const { data: requestData } = await supabase
    .from("service_requests")
    .select("total_bids, matching_radius_miles")
    .eq("id", request.id)
    .single();

  if (!requestData) {
    logger.error(`Request not found: ${request.id}`);
    return;
  }

  if (requestData.total_bids > 0) {
    logger.info(
      `Request ${request.id} has ${requestData.total_bids} bids. Continuing as normal.`
    );
    return;
  }

  logger.warn(`No bids for request ${request.id}. Expanding radius.`);

  // Expand radius
  const newRadius = requestData.matching_radius_miles + 10;

  await supabase
    .from("service_requests")
    .update({
      matching_radius_miles: newRadius,
      bid_window_end: new Date(Date.now() + 30 * 60 * 1000).toISOString(),
    })
    .eq("id", request.id);

  // Find new providers
  const { data: newCandidates } = await supabase.rpc("find_nearby_providers", {
    request_longitude: request.location.coordinates[0],
    request_latitude: request.location.coordinates[1],
    category_id: request.category_id,
    radius_miles: newRadius,
  });

  if (!newCandidates || newCandidates.length === 0) {
    logger.warn(
      `Still no providers for request ${request.id} after radius expansion`
    );
    await notifyCustomerNoBidsReceived(request);
    return;
  }

  // Get existing matched providers
  const { data: existingMatches } = await supabase
    .from("matched_providers")
    .select("provider_id")
    .eq("request_id", request.id);

  const existingIds = new Set(
    (existingMatches || []).map((m: any) => m.provider_id)
  );

  // Filter to new providers only
  const newProviders = (newCandidates as MatchedProvider[])
    .filter((p) => !existingIds.has(p.provider_id))
    .slice(0, 5); // Re-notify up to 5 new providers

  if (newProviders.length === 0) {
    logger.warn(
      `No new providers found after expanding radius for request ${request.id}`
    );
    return;
  }

  logger.info(
    `Found ${newProviders.length} new providers. Re-notifying with expanded radius.`
  );

  // Insert new matched providers
  const matchRecords = newProviders.map((provider) => ({
    request_id: request.id,
    provider_id: provider.provider_id,
    composite_score: provider.composite_score,
    distance_miles: provider.distance_miles,
    notified_at: new Date().toISOString(),
    notification_channels: { email: true, push: true, sms: true },
  }));

  await supabase.from("matched_providers").insert(matchRecords);

  // Send notifications
  for (const provider of newProviders) {
    try {
      await sendEmailNotification(provider as MatchedProvider, request, 0, 0);
    } catch (error: any) {
      logger.error(`Failed to notify provider: ${error.message}`);
    }
  }
}

/**
 * Helper functions for notifications
 */

async function sendEmailNotification(
  provider: MatchedProvider,
  request: ServiceRequest,
  rankIndex: number,
  totalMatches: number
) {
  const rankText =
    totalMatches > 0 ? ` (${rankIndex + 1} of ${totalMatches})` : " (re-send)";

  return await axios.post(
    `${process.env.SENDGRID_API_URL}/v3/mail/send`,
    {
      personalizations: [
        {
          to: [{ email: provider.email }],
          dynamic_template_data: {
            provider_name: provider.business_name,
            job_title: request.title,
            location:
              `${request.address_city}, ${request.address_state}`,
            distance_miles: provider.distance_miles.toFixed(1),
            budget_min: request.budget_min,
            budget_max: request.budget_max,
            request_id: request.id,
            rank_text: rankText,
            dashboard_link: `https://dashboard.marketplace.example.com/requests/${request.id}`,
          },
        },
      ],
      from: { email: process.env.SENDGRID_FROM_EMAIL },
      template_id: process.env.SENDGRID_TEMPLATE_ID_BID_NOTIFICATION,
    },
    {
      headers: {
        Authorization: `Bearer ${process.env.SENDGRID_API_KEY}`,
      },
    }
  );
}

async function sendPushNotification(
  fcmToken: string,
  jobTitle: string,
  city: string
) {
  return await axios.post(
    "https://fcm.googleapis.com/fcm/send",
    {
      to: fcmToken,
      notification: {
        title: "New Job Match",
        body: `${jobTitle} - ${city}`,
      },
      data: {
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
    },
    {
      headers: {
        Authorization: `key=${process.env.FCM_SERVER_KEY}`,
      },
    }
  );
}

async function sendSMSNotification(
  phone: string,
  jobTitle: string,
  city: string,
  distance: string
) {
  const twilio = require("twilio");
  const client = twilio(
    process.env.TWILIO_ACCOUNT_SID,
    process.env.TWILIO_AUTH_TOKEN
  );

  return await client.messages.create({
    body: `New job match: ${jobTitle} in ${city} (${distance} miles away). Check the app to bid!`,
    from: process.env.TWILIO_PHONE_NUMBER,
    to: phone,
  });
}

async function notifyCustomerNoProviders(request: ServiceRequest) {
  await supabase.from("notifications").insert({
    user_id: request.customer_id,
    user_role: "customer",
    type: "no_providers_available",
    title: "No Providers Available",
    body: `We couldn't find verified providers for your request in the requested area. Please try expanding your service area or contact support.`,
    data: { request_id: request.id },
  });
}

async function notifyCustomerNoBidsReceived(request: ServiceRequest) {
  await supabase.from("notifications").insert({
    user_id: request.customer_id,
    user_role: "customer",
    type: "no_bids_received",
    title: "We're Still Looking for Providers",
    body: `We expanded our search area but haven't found providers yet. You'll be notified when bids come in.`,
    data: { request_id: request.id },
  });
}
