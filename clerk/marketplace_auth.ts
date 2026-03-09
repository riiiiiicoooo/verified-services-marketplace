/**
 * Clerk Authentication Configuration
 * Multi-tenant authentication with three user types:
 * - Customers: End-users seeking services
 * - Providers: Service professionals (verified)
 * - Operators: Platform administrators
 */

import { Clerk } from "@clerk/clerk-sdk-node";
import { clerkClient } from "@clerk/nextjs/server";
import { createClient } from "@supabase/supabase-js";

const clerk = new Clerk({
  apiKey: process.env.CLERK_SECRET_KEY,
});

// ============================================================================
// User Role Types
// ============================================================================

export enum UserRole {
  CUSTOMER = "customer",
  PROVIDER = "provider",
  OPERATOR = "operator",
}

// ============================================================================
// Authentication Middleware
// ============================================================================

/**
 * Verify user role for protected routes
 */
export async function requireRole(
  userId: string,
  requiredRole: UserRole
): Promise<boolean> {
  try {
    const user = await clerkClient.users.getUser(userId);

    const userRole =
      user.publicMetadata?.marketplace_role ||
      user.unsafeMetadata?.marketplace_role;

    return userRole === requiredRole;
  } catch (error) {
    console.error("Failed to verify role:", error);
    return false;
  }
}

/**
 * Get user's marketplace role
 */
export async function getUserRole(userId: string): Promise<UserRole | null> {
  try {
    const user = await clerkClient.users.getUser(userId);
    return (
      (user.publicMetadata?.marketplace_role as UserRole) ||
      (user.unsafeMetadata?.marketplace_role as UserRole) ||
      null
    );
  } catch (error) {
    console.error("Failed to get user role:", error);
    return null;
  }
}

// ============================================================================
// Customer Signup
// ============================================================================

export async function createCustomerAccount(
  email: string,
  firstName: string,
  lastName: string,
  phone?: string,
  organizationId?: string
): Promise<{ userId: string; success: boolean; error?: string }> {
  try {
    // Create Clerk user
    const user = await clerkClient.users.createUser({
      emailAddress: [email],
      firstName,
      lastName,
      phoneNumber: phone ? [phone] : undefined,
      publicMetadata: {
        marketplace_role: UserRole.CUSTOMER,
      },
      unsafeMetadata: {
        marketplace_onboarding_complete: false,
      },
    });

    // If organization provided, add user to it
    if (organizationId) {
      await clerkClient.organizations.createOrganizationMembership(
        organizationId,
        {
          userId: user.id,
          role: "basic_member",
        }
      );
    }

    // Create customer profile in Supabase
    const supabase = createClient(
      process.env.SUPABASE_URL!,
      process.env.SUPABASE_ANON_KEY!
    );

    await supabase.from("customers").insert([
      {
        auth_user_id: user.id,
        name: `${firstName} ${lastName}`,
        email,
        phone,
      },
    ]);

    console.log(`Created customer account for ${email}`);

    return { userId: user.id, success: true };
  } catch (error: any) {
    console.error("Failed to create customer account:", error);
    return {
      userId: "",
      success: false,
      error: error.message,
    };
  }
}

// ============================================================================
// Provider Signup
// ============================================================================

export async function createProviderAccount(
  email: string,
  firstName: string,
  lastName: string,
  businessName: string,
  phone: string,
  serviceLocationLat: number,
  serviceLocationLng: number
): Promise<{ userId: string; success: boolean; error?: string }> {
  try {
    // Create Clerk user
    const user = await clerkClient.users.createUser({
      emailAddress: [email],
      firstName,
      lastName,
      phoneNumber: [phone],
      publicMetadata: {
        marketplace_role: UserRole.PROVIDER,
      },
      unsafeMetadata: {
        marketplace_onboarding_complete: false,
        provider_verification_status: "pending",
      },
    });

    // Create provider profile in Supabase
    const supabase = createClient(
      process.env.SUPABASE_URL!,
      process.env.SUPABASE_ANON_KEY!
    );

    // Convert lat/lng to PostGIS point
    const location = {
      type: "Point",
      coordinates: [serviceLocationLng, serviceLocationLat],
    };

    const { data: provider, error } = await supabase
      .from("providers")
      .insert([
        {
          auth_user_id: user.id,
          business_name: businessName,
          contact_name: `${firstName} ${lastName}`,
          email,
          phone,
          service_location: location,
          verification_status: "pending",
          is_active: false,
        },
      ])
      .select()
      .single();

    if (error) {
      throw new Error(`Failed to create provider profile: ${error.message}`);
    }

    console.log(`Created provider account for ${email}`);

    // Trigger verification pipeline via webhook
    const triggerDevWebhook = process.env.TRIGGER_DEV_WEBHOOK_URL;
    if (triggerDevWebhook) {
      await fetch(triggerDevWebhook, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          event: "provider.created",
          data: {
            provider_id: provider.id,
            first_name: firstName,
            last_name: lastName,
            email,
            phone,
            business_name: businessName,
            state: provider.address_state,
          },
        }),
      });
    }

    return { userId: user.id, success: true };
  } catch (error: any) {
    console.error("Failed to create provider account:", error);
    return {
      userId: "",
      success: false,
      error: error.message,
    };
  }
}

// ============================================================================
// Operator/Admin Signup
// ============================================================================

/**
 * Create operator account (internal use only)
 * Should be protected and only called by existing operators
 */
export async function createOperatorAccount(
  email: string,
  firstName: string,
  lastName: string,
  organizationId: string
): Promise<{ userId: string; success: boolean; error?: string }> {
  try {
    // Create Clerk user
    const user = await clerkClient.users.createUser({
      emailAddress: [email],
      firstName,
      lastName,
      publicMetadata: {
        marketplace_role: UserRole.OPERATOR,
      },
    });

    // Add to operator organization
    await clerkClient.organizations.createOrganizationMembership(
      organizationId,
      {
        userId: user.id,
        role: "admin",
      }
    );

    console.log(`Created operator account for ${email}`);

    return { userId: user.id, success: true };
  } catch (error: any) {
    console.error("Failed to create operator account:", error);
    return {
      userId: "",
      success: false,
      error: error.message,
    };
  }
}

// ============================================================================
// Organization Management (Multi-Service Organizations)
// ============================================================================

/**
 * Create organization for Multi-Service Organizations (MSOs)
 * Allows large service providers to manage multiple brands under one account
 */
export async function createMSO(
  msoName: string,
  slug: string,
  ownerUserId: string
): Promise<{ orgId: string; success: boolean; error?: string }> {
  try {
    const organization = await clerkClient.organizations.createOrganization({
      name: msoName,
      slug,
    });

    // Add owner
    await clerkClient.organizations.createOrganizationMembership(
      organization.id,
      {
        userId: ownerUserId,
        role: "admin",
      }
    );

    console.log(`Created MSO organization: ${msoName} (${organization.id})`);

    return { orgId: organization.id, success: true };
  } catch (error: any) {
    console.error("Failed to create MSO organization:", error);
    return {
      orgId: "",
      success: false,
      error: error.message,
    };
  }
}

/**
 * Add sub-provider under MSO
 */
export async function addProviderToMSO(
  msoId: string,
  email: string,
  businessName: string,
  role: "admin" | "member" = "member"
): Promise<{ userId: string; success: boolean; error?: string }> {
  try {
    // Create provider user
    const user = await clerkClient.users.createUser({
      emailAddress: [email],
      firstName: businessName.split(" ")[0],
      lastName: businessName.split(" ").slice(1).join(" ") || "Service",
      publicMetadata: {
        marketplace_role: UserRole.PROVIDER,
      },
    });

    // Add to MSO organization
    await clerkClient.organizations.createOrganizationMembership(msoId, {
      userId: user.id,
      role,
    });

    console.log(`Added provider ${email} to MSO ${msoId}`);

    return { userId: user.id, success: true };
  } catch (error: any) {
    console.error("Failed to add provider to MSO:", error);
    return {
      userId: "",
      success: false,
      error: error.message,
    };
  }
}

// ============================================================================
// Session Management
// ============================================================================

/**
 * Get user session with marketplace context
 */
export async function getMarketplaceSession(userId: string): Promise<{
  userId: string;
  role: UserRole | null;
  organization?: { id: string; name: string };
  verified?: boolean;
}> {
  try {
    const user = await clerkClient.users.getUser(userId);
    const role = (user.publicMetadata?.marketplace_role ||
      user.unsafeMetadata?.marketplace_role) as UserRole | null;

    // Get organization if user is part of one
    let organization;
    const memberships = await clerkClient.users.getOrganizationMemberships(
      userId
    );

    if (memberships.length > 0) {
      const org = await clerkClient.organizations.getOrganization(
        memberships[0].organization.id
      );
      organization = {
        id: org.id,
        name: org.name,
      };
    }

    // Get verification status for providers
    let verified = false;
    if (role === UserRole.PROVIDER) {
      const supabase = createClient(
        process.env.SUPABASE_URL!,
        process.env.SUPABASE_ANON_KEY!
      );

      const { data: provider } = await supabase
        .from("providers")
        .select("verification_status")
        .eq("auth_user_id", userId)
        .single();

      verified = provider?.verification_status === "verified";
    }

    return {
      userId,
      role,
      organization,
      verified,
    };
  } catch (error) {
    console.error("Failed to get marketplace session:", error);
    return { userId, role: null };
  }
}

// ============================================================================
// Role-Based Permissions
// ============================================================================

/**
 * Permission checks for different user roles
 */
export const Permissions = {
  customer: {
    canCreateRequest: true,
    canViewOwnRequests: true,
    canViewProviderProfiles: true,
    canReviewProviders: true,
    canAccessPaymentInfo: true,
  },

  provider: {
    canViewMatchedRequests: true,
    canSubmitBids: true,
    canCompleteJobs: true,
    canViewEarnings: true,
    canUpdateProfile: true,
    canViewDisputes: true,
  },

  operator: {
    canVerifyProviders: true,
    canSuspendProviders: true,
    canResolveDisputes: true,
    canViewAnalytics: true,
    canAccessAdminPanel: true,
    canManageCategories: true,
    canViewPaymentInfo: true,
  },
};

/**
 * Check if user has permission for an action
 */
export async function hasPermission(
  userId: string,
  action: string
): Promise<boolean> {
  const role = await getUserRole(userId);
  if (!role) return false;

  const rolePermissions = Permissions[role as keyof typeof Permissions];
  return (rolePermissions as any)?.[action] ?? false;
}

// ============================================================================
// Webhook: Post-signup Actions
// ============================================================================

/**
 * Webhook handler for post-signup actions
 * Triggered by Clerk after user creation
 */
export async function handleUserCreated(event: any): Promise<void> {
  const user = event.data;
  const role = user.public_metadata?.marketplace_role;

  try {
    if (role === UserRole.CUSTOMER) {
      // Send welcome email to customer
      console.log(`Sending welcome email to customer: ${user.email_addresses[0]}`);
      // Would integrate with SendGrid here
    } else if (role === UserRole.PROVIDER) {
      // Send provider onboarding email
      console.log(
        `Sending onboarding email to provider: ${user.email_addresses[0]}`
      );
      // Would integrate with SendGrid here
    } else if (role === UserRole.OPERATOR) {
      // Log operator creation for audit
      console.log(`Operator created: ${user.email_addresses[0]}`);
    }
  } catch (error) {
    console.error("Failed to handle user creation webhook:", error);
  }
}

// ============================================================================
// Sync: Clerk → Supabase
// ============================================================================

/**
 * Sync user metadata from Clerk to Supabase
 * Called periodically or on user update
 */
export async function syncUserMetadata(userId: string): Promise<void> {
  try {
    const user = await clerkClient.users.getUser(userId);
    const role = (user.publicMetadata?.marketplace_role ||
      user.unsafeMetadata?.marketplace_role) as UserRole | null;

    // Update appropriate table based on role
    const supabase = createClient(
      process.env.SUPABASE_URL!,
      process.env.SUPABASE_ANON_KEY!
    );

    if (role === UserRole.CUSTOMER) {
      await supabase
        .from("customers")
        .update({
          email: user.emailAddresses[0]?.emailAddress,
          name: `${user.firstName} ${user.lastName}`,
          phone: user.phoneNumbers[0]?.phoneNumber,
        })
        .eq("auth_user_id", userId);
    } else if (role === UserRole.PROVIDER) {
      await supabase
        .from("providers")
        .update({
          email: user.emailAddresses[0]?.emailAddress,
          contact_name: `${user.firstName} ${user.lastName}`,
          phone: user.phoneNumbers[0]?.phoneNumber,
        })
        .eq("auth_user_id", userId);
    }

    console.log(`Synced user metadata for ${userId}`);
  } catch (error) {
    console.error("Failed to sync user metadata:", error);
  }
}
