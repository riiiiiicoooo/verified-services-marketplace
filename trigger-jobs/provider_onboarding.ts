import { TriggerEvent, logger } from "@trigger.dev/sdk";
import { client } from "@trigger.dev/sdk";
import { createClient } from "@supabase/supabase-js";
import axios from "axios";

const supabase = createClient(
  process.env.SUPABASE_URL || "",
  process.env.SUPABASE_ANON_KEY || ""
);

interface ProviderOnboardingEvent {
  provider_id: string;
  first_name: string;
  last_name: string;
  email: string;
  phone: string;
  business_name: string;
  state: string;
  trade_license_number?: string;
  insurance_policy_number?: string;
  insurance_expiry?: string;
}

/**
 * Provider Onboarding Job
 * Long-running verification pipeline orchestration
 * Coordinates: Checkr background check → License verification → Insurance verification
 * → Provider activation → Stripe Connect account creation
 */
export const providerOnboarding = client.defineJob({
  id: "provider-onboarding",
  name: "Provider Verification & Onboarding Pipeline",
  version: "1.0.0",
  trigger: {
    events: ["provider.created"],
  },
  run: async (
    event: ProviderOnboardingEvent,
    { io, ctx, runTrigger }: any
  ) => {
    logger.info(`Starting onboarding pipeline for provider: ${event.provider_id}`);

    // Step 1: Update provider status to documents_submitted
    await io.runStep("update-to-submitted", async () => {
      const { error } = await supabase
        .from("providers")
        .update({ verification_status: "documents_submitted" })
        .eq("id", event.provider_id);

      if (error) throw error;
      logger.info(`Updated provider to documents_submitted status`);
    });

    // Step 2: Initiate Checkr background check
    const checkrCandidateId = await io.runStep(
      "checkr-create-candidate",
      async () => {
        const response = await axios.post(
          "https://api.checkr.com/v1/candidates",
          {
            first_name: event.first_name,
            last_name: event.last_name,
            email: event.email,
            phone: event.phone,
          },
          {
            auth: {
              username: process.env.CHECKR_API_KEY || "",
              password: "",
            },
          }
        );

        logger.info(
          `Created Checkr candidate: ${response.data.id}`
        );
        return response.data.id;
      }
    );

    // Step 3: Create background check with Checkr
    const checkrReportId = await io.runStep(
      "checkr-create-report",
      async () => {
        const response = await axios.post(
          `https://api.checkr.com/v1/candidates/${checkrCandidateId}/reports`,
          {
            package: "standard_plus",
          },
          {
            auth: {
              username: process.env.CHECKR_API_KEY || "",
              password: "",
            },
          }
        );

        logger.info(
          `Created Checkr background report: ${response.data.id}`
        );

        // Store Checkr reference IDs
        await supabase
          .from("verifications")
          .insert({
            provider_id: event.provider_id,
            check_type: "criminal_background",
            status: "in_progress",
            vendor: "checkr",
            vendor_ref_id: response.data.id,
          });

        return response.data.id;
      }
    );

    // Step 4: Wait for Checkr webhook callback (with timeout)
    const checkrResult = await io.wait(
      "wait-for-checkr-result",
      {
        timeout: 7 * 24 * 60 * 60 * 1000, // 7 days
        pollConfig: {
          enabled: true,
          intervalMs: 60000, // Check every minute
        },
      },
      async () => {
        // Poll Checkr for report status
        const checkResponse = await axios.get(
          `https://api.checkr.com/v1/reports/${checkrReportId}`,
          {
            auth: {
              username: process.env.CHECKR_API_KEY || "",
              password: "",
            },
          }
        );

        const reportStatus = checkResponse.data.status; // pending, completed, consider

        if (reportStatus === "completed" || reportStatus === "consider") {
          logger.info(`Checkr report completed with status: ${reportStatus}`);
          return {
            completed: true,
            status: reportStatus,
            data: checkResponse.data,
          };
        }

        // Not ready yet
        return { completed: false };
      }
    );

    if (!checkrResult.completed) {
      logger.error(`Checkr report timed out for provider ${event.provider_id}`);
      await markVerificationFailed(
        event.provider_id,
        "criminal_background",
        "Background check timed out"
      );
      return {
        success: false,
        error: "Background check verification timeout",
      };
    }

    // Step 5: Evaluate Checkr result
    const checkrPassed =
      checkrResult.status === "completed" &&
      (!checkrResult.data.adjudication ||
        checkrResult.data.adjudication.status === "clear");

    if (!checkrPassed) {
      logger.warn(
        `Checkr background check failed for provider ${event.provider_id}`
      );
      await markVerificationFailed(
        event.provider_id,
        "criminal_background",
        `Background check returned: ${checkrResult.status}`
      );

      await notifyOperatorReviewNeeded(
        event.provider_id,
        event.business_name,
        "Background check requires review"
      );

      return {
        success: false,
        error: "Background check failed",
        checkr_status: checkrResult.status,
      };
    }

    logger.info(`Checkr background check passed for provider`);

    // Step 6: Update verification record
    await io.runStep("update-background-passed", async () => {
      const { error } = await supabase
        .from("verifications")
        .update({
          status: "passed",
          verified_at: new Date().toISOString(),
        })
        .match({
          provider_id: event.provider_id,
          check_type: "criminal_background",
        });

      if (error) throw error;
    });

    // Step 7: Verify trade license (if number provided)
    if (event.trade_license_number) {
      await io.runStep("verify-trade-license", async () => {
        try {
          const licenseResult = await verifyLicense(
            event.state,
            event.trade_license_number!
          );

          const status = licenseResult.valid ? "passed" : "failed";

          await supabase.from("verifications").insert({
            provider_id: event.provider_id,
            check_type: "trade_license",
            status: status,
            document_number: event.trade_license_number,
            vendor: "state_licensing_board",
            failure_reason: licenseResult.error,
            verified_at: licenseResult.valid
              ? new Date().toISOString()
              : null,
          });

          logger.info(
            `Trade license verification: ${status}`
          );

          if (!licenseResult.valid) {
            throw new Error(
              `License verification failed: ${licenseResult.error}`
            );
          }
        } catch (error: any) {
          logger.warn(
            `Trade license verification error: ${error.message}. Continuing.`
          );
        }
      });
    }

    // Step 8: Verify insurance (if policy number provided)
    if (event.insurance_policy_number) {
      await io.runStep("verify-insurance", async () => {
        try {
          const insuranceValid =
            event.insurance_expiry &&
            new Date(event.insurance_expiry) > new Date();

          const status = insuranceValid ? "passed" : "failed";

          await supabase.from("verifications").insert({
            provider_id: event.provider_id,
            check_type: "general_liability_insurance",
            status: status,
            document_number: event.insurance_policy_number,
            expires_at: event.insurance_expiry,
            vendor: "provider_submitted",
            failure_reason: insuranceValid ? null : "Policy expired",
            verified_at: new Date().toISOString(),
          });

          logger.info(`Insurance verification: ${status}`);

          if (!insuranceValid) {
            throw new Error("Insurance policy has expired");
          }
        } catch (error: any) {
          logger.warn(
            `Insurance verification error: ${error.message}. Continuing.`
          );
        }
      });
    }

    // Step 9: Check all verifications passed
    const { data: allVerifications } = await io.runStep(
      "check-all-verifications",
      async () => {
        return await supabase
          .from("verifications")
          .select("*")
          .eq("provider_id", event.provider_id);
      }
    );

    const failedChecks = (allVerifications || []).filter(
      (v: any) => v.status === "failed"
    );

    if (failedChecks.length > 0) {
      logger.warn(
        `Some verifications failed for provider ${event.provider_id}`
      );

      await supabase
        .from("providers")
        .update({ verification_status: "operator_review" })
        .eq("id", event.provider_id);

      await notifyOperatorReviewNeeded(
        event.provider_id,
        event.business_name,
        `${failedChecks.length} verification(s) failed`
      );

      return {
        success: false,
        error: "Some verifications failed",
        failed_checks: failedChecks.map((c: any) => c.check_type),
      };
    }

    // Step 10: Create Stripe Connect Express account
    const stripeAccountId = await io.runStep(
      "stripe-create-account",
      async () => {
        const response = await axios.post(
          "https://api.stripe.com/v1/accounts",
          {
            type: "express",
            country: "US",
            email: event.email,
            business_profile: {
              name: event.business_name,
              url: process.env.MARKETPLACE_BASE_URL,
            },
            tos_acceptance: {
              service_agreement: "recipient",
              date: Math.floor(Date.now() / 1000),
              ip: "127.0.0.1",
            },
            metadata: {
              provider_id: event.provider_id,
            },
          },
          {
            auth: {
              username: process.env.STRIPE_SECRET_KEY || "",
              password: "",
            },
          }
        );

        logger.info(`Created Stripe Connect account: ${response.data.id}`);
        return response.data.id;
      }
    );

    // Step 11: Activate provider in database
    await io.runStep("activate-provider", async () => {
      const { error } = await supabase
        .from("providers")
        .update({
          verification_status: "verified",
          is_active: true,
          stripe_account_id: stripeAccountId,
        })
        .eq("id", event.provider_id);

      if (error) throw error;
      logger.info(`Provider activated and verified`);
    });

    // Step 12: Send welcome email
    await io.runStep("send-welcome-email", async () => {
      try {
        await sendWelcomeEmail(event.email, event.business_name);
        logger.info(`Welcome email sent to ${event.email}`);
      } catch (error: any) {
        logger.warn(`Failed to send welcome email: ${error.message}`);
      }
    });

    // Step 13: Create onboarding task for provider
    await io.runStep("create-onboarding-notification", async () => {
      await supabase.from("notifications").insert({
        user_id: event.provider_id, // Note: would need auth_user_id mapping
        user_role: "provider",
        type: "verification_complete",
        title: "Welcome to the Verified Marketplace!",
        body: "Your verification is complete. You can now start receiving job matches.",
        data: {
          provider_id: event.provider_id,
          onboarding_url: `https://dashboard.marketplace.example.com/onboarding/complete`,
        },
      });
    });

    logger.info(
      `Provider onboarding completed successfully for: ${event.provider_id}`
    );

    return {
      success: true,
      provider_id: event.provider_id,
      stripe_account_id: stripeAccountId,
      verification_status: "verified",
      is_active: true,
    };
  },
});

/**
 * Helper: Verify trade license via state board APIs
 */
async function verifyLicense(
  state: string,
  licenseNumber: string
): Promise<{ valid: boolean; error?: string }> {
  // This is a placeholder - would integrate with actual state licensing board APIs
  // Different states have different APIs (California Board of Contractors, etc.)

  logger.info(`Verifying trade license: ${state} - ${licenseNumber}`);

  // Mock implementation - in production, call actual state APIs
  if (!licenseNumber || licenseNumber.length < 5) {
    return { valid: false, error: "Invalid license number format" };
  }

  // Assume valid for now
  return { valid: true };
}

/**
 * Helper: Send welcome email
 */
async function sendWelcomeEmail(email: string, businessName: string) {
  return await axios.post(
    `${process.env.SENDGRID_API_URL}/v3/mail/send`,
    {
      personalizations: [
        {
          to: [{ email }],
          dynamic_template_data: {
            business_name: businessName,
            dashboard_link: process.env.MARKETPLACE_BASE_URL,
          },
        },
      ],
      from: { email: process.env.SENDGRID_FROM_EMAIL },
      template_id: process.env.SENDGRID_TEMPLATE_ID_PROVIDER_WELCOME,
    },
    {
      headers: {
        Authorization: `Bearer ${process.env.SENDGRID_API_KEY}`,
      },
    }
  );
}

/**
 * Helper: Notify operator of verification issue
 */
async function notifyOperatorReviewNeeded(
  providerId: string,
  businessName: string,
  reason: string
) {
  try {
    await supabase.from("notifications").insert({
      user_id: process.env.OPERATOR_USER_ID,
      user_role: "operator",
      type: "provider_verification_review_needed",
      title: `Manual Review Required: ${businessName}`,
      body: reason,
      data: {
        provider_id: providerId,
        review_url: `https://operator.marketplace.example.com/verification/${providerId}`,
      },
    });
  } catch (error: any) {
    logger.warn(`Failed to notify operator: ${error.message}`);
  }
}

/**
 * Helper: Mark verification as failed
 */
async function markVerificationFailed(
  providerId: string,
  checkType: string,
  failureReason: string
) {
  const { error } = await supabase
    .from("verifications")
    .update({
      status: "failed",
      failure_reason: failureReason,
    })
    .match({ provider_id: providerId, check_type: checkType });

  if (error) {
    logger.error(`Failed to mark verification as failed: ${error.message}`);
  }
}
