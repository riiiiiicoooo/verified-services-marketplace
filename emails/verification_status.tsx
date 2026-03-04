import React from "react";
import {
  Body,
  Button,
  Container,
  Head,
  Hr,
  Html,
  Img,
  Link,
  Preview,
  Row,
  Section,
  Text,
  Column,
} from "@react-email/components";

interface VerificationStatusProps {
  providerName: string;
  status: "approved" | "rejected" | "pending_review" | "in_progress";
  verificationChecks?: {
    name: string;
    status: "passed" | "failed" | "pending";
    failureReason?: string;
  }[];
  nextSteps?: string;
  rejectionReason?: string;
  dashboardLink: string;
  supportEmail?: string;
}

const baseUrl = process.env.NEXT_PUBLIC_BASE_URL || "https://marketplace.example.com";

const getStatusColor = (status: string) => {
  switch (status) {
    case "passed":
      return "#10b981";
    case "failed":
      return "#ef4444";
    case "pending":
      return "#f59e0b";
    default:
      return "#6b7280";
  }
};

const getStatusIcon = (status: string) => {
  switch (status) {
    case "passed":
      return "✓";
    case "failed":
      return "✕";
    case "pending":
      return "⏳";
    default:
      return "•";
  }
};

export const VerificationStatus: React.FC<VerificationStatusProps> = ({
  providerName,
  status,
  verificationChecks = [],
  nextSteps,
  rejectionReason,
  dashboardLink,
  supportEmail = "support@marketplace.example.com",
}) => {
  const isApproved = status === "approved";
  const isRejected = status === "rejected";
  const isPending = status === "pending_review";
  const isInProgress = status === "in_progress";

  return (
    <Html>
      <Head />
      <Preview>
        {isApproved
          ? `Welcome! Your verification is complete`
          : `Verification status update for ${providerName}`}
      </Preview>
      <Body style={main}>
        <Container style={container}>
          {/* Header */}
          <Section style={header}>
            <Img
              src={`${baseUrl}/logo.png`}
              width="40"
              height="40"
              alt="Verified Services Marketplace"
            />
            <Text style={headerTitle}>
              {isApproved
                ? "Verification Complete!"
                : isRejected
                ? "Verification Review Update"
                : "Verification In Progress"}
            </Text>
          </Section>

          {/* Main content */}
          <Section style={content}>
            <Text style={greeting}>Hi {providerName},</Text>

            {/* Status badge */}
            <Section style={statusBadgeSection}>
              {isApproved && (
                <>
                  <Text style={{ ...statusBadge, backgroundColor: "#d1fae5" }}>
                    <span style={{ color: "#10b981", fontSize: "20px" }}>✓</span>{" "}
                    Approved & Verified
                  </Text>
                  <Text style={approvedMessage}>
                    Congratulations! Your verification is complete and your
                    account is now active. You can start receiving job matches
                    from customers in your service area.
                  </Text>
                </>
              )}

              {isRejected && (
                <>
                  <Text style={{ ...statusBadge, backgroundColor: "#fee2e2" }}>
                    <span style={{ color: "#ef4444", fontSize: "20px" }}>✕</span>{" "}
                    Verification Incomplete
                  </Text>
                  <Text style={rejectionMessage}>
                    We were unable to complete your verification at this time.
                    {rejectionReason && (
                      <>
                        <br />
                        <strong>Reason:</strong> {rejectionReason}
                      </>
                    )}
                  </Text>
                </>
              )}

              {isPending && (
                <>
                  <Text style={{ ...statusBadge, backgroundColor: "#fef3c7" }}>
                    <span style={{ color: "#f59e0b", fontSize: "20px" }}>
                      ⏳
                    </span>{" "}
                    Under Review
                  </Text>
                  <Text style={pendingMessage}>
                    Your verification documents have been received and are
                    being reviewed by our team. We typically complete reviews
                    within 1-2 business days.
                  </Text>
                </>
              )}

              {isInProgress && (
                <>
                  <Text style={{ ...statusBadge, backgroundColor: "#dbeafe" }}>
                    <span style={{ color: "#3b82f6", fontSize: "20px" }}>
                      ◐
                    </span>{" "}
                    In Progress
                  </Text>
                  <Text style={inProgressMessage}>
                    We're processing your verification checks. You'll be
                    notified as soon as we have an update.
                  </Text>
                </>
              )}
            </Section>

            {/* Verification checks */}
            {verificationChecks.length > 0 && (
              <Section style={checksSection}>
                <Text style={sectionTitle}>Verification Checks</Text>

                {verificationChecks.map((check, index) => (
                  <Row
                    key={index}
                    style={{
                      marginBottom: index < verificationChecks.length - 1 ? "12px" : "0",
                      paddingBottom: "12px",
                      borderBottom:
                        index < verificationChecks.length - 1
                          ? "1px solid #e5e7eb"
                          : "none",
                    }}
                  >
                    <Column style={{ width: "30px", paddingRight: "8px" }}>
                      <Text
                        style={{
                          fontSize: "16px",
                          color: getStatusColor(check.status),
                          textAlign: "center",
                          margin: "0",
                        }}
                      >
                        {getStatusIcon(check.status)}
                      </Text>
                    </Column>
                    <Column>
                      <Text style={checkName}>{check.name}</Text>
                      {check.failureReason && (
                        <Text style={failureReason}>
                          {check.failureReason}
                        </Text>
                      )}
                    </Column>
                    <Column style={{ width: "80px", textAlign: "right" }}>
                      <Text
                        style={{
                          fontSize: "11px",
                          fontWeight: "600",
                          color: getStatusColor(check.status),
                          margin: "0",
                          textTransform: "uppercase",
                        }}
                      >
                        {check.status === "passed"
                          ? "Passed"
                          : check.status === "failed"
                          ? "Failed"
                          : "Pending"}
                      </Text>
                    </Column>
                  </Row>
                ))}
              </Section>
            )}

            {/* Next steps - Approved */}
            {isApproved && (
              <Section style={nextStepsSection}>
                <Text style={sectionTitle}>What's Next?</Text>

                <Row style={{ marginBottom: "12px" }}>
                  <Column style={{ width: "30px", paddingRight: "8px" }}>
                    <Text style={stepNumber}>1</Text>
                  </Column>
                  <Column>
                    <Text style={stepText}>
                      <strong>Set up your profile</strong> - Add a profile photo
                      and bio to help customers get to know you.
                    </Text>
                  </Column>
                </Row>

                <Row style={{ marginBottom: "12px" }}>
                  <Column style={{ width: "30px", paddingRight: "8px" }}>
                    <Text style={stepNumber}>2</Text>
                  </Column>
                  <Column>
                    <Text style={stepText}>
                      <strong>Configure your services</strong> - Select the
                      service categories you offer and set your service area.
                    </Text>
                  </Column>
                </Row>

                <Row style={{ marginBottom: "12px" }}>
                  <Column style={{ width: "30px", paddingRight: "8px" }}>
                    <Text style={stepNumber}>3</Text>
                  </Column>
                  <Column>
                    <Text style={stepText}>
                      <strong>Set up Stripe payment</strong> - Complete your
                      Stripe Connect onboarding to receive payments.
                    </Text>
                  </Column>
                </Row>

                <Row>
                  <Column style={{ width: "30px", paddingRight: "8px" }}>
                    <Text style={stepNumber}>4</Text>
                  </Column>
                  <Column>
                    <Text style={stepText}>
                      <strong>Start accepting jobs</strong> - You'll begin
                      receiving matched job notifications from customers.
                    </Text>
                  </Column>
                </Row>
              </Section>
            )}

            {/* Next steps - Rejected */}
            {isRejected && (
              <Section style={nextStepsSection}>
                <Text style={sectionTitle}>How to Proceed</Text>

                <Text style={paragraph}>
                  {rejectionReason && (
                    <>
                      We identified the following issue(s) with your submission:{" "}
                      <strong>{rejectionReason}</strong>
                    </>
                  )}
                </Text>

                <Text style={paragraph}>
                  You have the following options:
                </Text>

                <Row style={{ marginBottom: "12px" }}>
                  <Column style={{ width: "20px", paddingRight: "8px" }}>
                    <Text style={{ margin: "0", color: "#ef4444" }}>•</Text>
                  </Column>
                  <Column>
                    <Text style={optionText}>
                      <strong>Resubmit your application</strong> with corrected
                      information after addressing the issues above.
                    </Text>
                  </Column>
                </Row>

                <Row>
                  <Column style={{ width: "20px", paddingRight: "8px" }}>
                    <Text style={{ margin: "0", color: "#ef4444" }}>•</Text>
                  </Column>
                  <Column>
                    <Text style={optionText}>
                      <strong>Contact support</strong> if you have questions
                      about the rejection or need assistance.
                    </Text>
                  </Column>
                </Row>
              </Section>
            )}

            {/* CTA */}
            <Section style={ctaSection}>
              {isApproved && (
                <Button style={button} href={dashboardLink}>
                  Go to Dashboard
                </Button>
              )}
              {isRejected && (
                <>
                  <Button style={button} href={`${dashboardLink}/reapply`}>
                    Resubmit Application
                  </Button>
                  <Text style={{ margin: "12px 0 0 0" }}>
                    <Link href={`mailto:${supportEmail}`} style={supportLink}>
                      Contact Support →
                    </Link>
                  </Text>
                </>
              )}
              {(isPending || isInProgress) && (
                <Button style={button} href={dashboardLink}>
                  View Status
                </Button>
              )}
            </Section>

            {/* Benefits for verified providers */}
            {isApproved && (
              <Section style={benefitsSection}>
                <Text style={sectionTitle}>Benefits of Being Verified</Text>

                <Row style={{ marginBottom: "12px" }}>
                  <Column style={{ width: "24px", paddingRight: "8px" }}>
                    <Text style={{ fontSize: "18px", margin: "0" }}>⭐</Text>
                  </Column>
                  <Column>
                    <Text style={benefitText}>
                      <strong>Increased visibility</strong> - Appear in customer
                      searches and get matched to relevant jobs.
                    </Text>
                  </Column>
                </Row>

                <Row style={{ marginBottom: "12px" }}>
                  <Column style={{ width: "24px", paddingRight: "8px" }}>
                    <Text style={{ fontSize: "18px", margin: "0" }}>💰</Text>
                  </Column>
                  <Column>
                    <Text style={benefitText}>
                      <strong>Faster payments</strong> - Get paid within 3-5
                      business days, not 30-60.
                    </Text>
                  </Column>
                </Row>

                <Row style={{ marginBottom: "12px" }}>
                  <Column style={{ width: "24px", paddingRight: "8px" }}>
                    <Text style={{ fontSize: "18px", margin: "0" }}>🛡️</Text>
                  </Column>
                  <Column>
                    <Text style={benefitText}>
                      <strong>Protected platform</strong> - Secure escrow holds
                      funds until job completion.
                    </Text>
                  </Column>
                </Row>

                <Row>
                  <Column style={{ width: "24px", paddingRight: "8px" }}>
                    <Text style={{ fontSize: "18px", margin: "0" }}>📈</Text>
                  </Column>
                  <Column>
                    <Text style={benefitText}>
                      <strong>Build reputation</strong> - Earn ratings and
                      reviews to unlock preferred and elite tiers.
                    </Text>
                  </Column>
                </Row>
              </Section>
            )}

            {/* Support section */}
            <Section style={supportSection}>
              <Text style={supportTitle}>Questions?</Text>
              <Text style={paragraph}>
                Check out our{" "}
                <Link href={`${baseUrl}/help/providers`} style={linkStyle}>
                  provider help center
                </Link>{" "}
                or reach out to us at{" "}
                <Link href={`mailto:${supportEmail}`} style={linkStyle}>
                  {supportEmail}
                </Link>
                .
              </Text>
            </Section>
          </Section>

          {/* Footer */}
          <Hr style={{ margin: "32px 0", borderColor: "#e5e7eb" }} />
          <Section style={footer}>
            <Row>
              <Column>
                <Text style={footerText}>
                  © 2026 Verified Services Marketplace. All rights reserved.
                </Text>
              </Column>
            </Row>
            <Row>
              <Column style={{ textAlign: "center" }}>
                <Link href={`${baseUrl}/privacy`} style={footerLink}>
                  Privacy
                </Link>
                <Text style={{ margin: "0 8px", display: "inline" }}>•</Text>
                <Link href={`${baseUrl}/terms`} style={footerLink}>
                  Terms
                </Link>
                <Text style={{ margin: "0 8px", display: "inline" }}>•</Text>
                <Link href={`${baseUrl}/help`} style={footerLink}>
                  Help
                </Link>
              </Column>
            </Row>
          </Section>
        </Container>
      </Body>
    </Html>
  );
};

// Styles
const main = {
  backgroundColor: "#f9fafb",
  fontFamily:
    '-apple-system, BlinkMacSystemFont, "Segoe UI", "Roboto", "Oxygen", "Ubuntu", "Cantarell", "Fira Sans", "Droid Sans", "Helvetica Neue", sans-serif',
};

const container = {
  backgroundColor: "#ffffff",
  margin: "0 auto",
  padding: "20px 0",
  marginBottom: "64px",
};

const header = {
  backgroundColor: "#003d82",
  color: "#ffffff",
  padding: "24px",
  textAlign: "center" as const,
};

const headerTitle = {
  fontSize: "28px",
  fontWeight: "bold",
  margin: "8px 0 0 0",
};

const content = {
  padding: "32px 24px",
};

const greeting = {
  fontSize: "16px",
  fontWeight: "bold",
  margin: "0 0 16px 0",
  color: "#1f2937",
};

const statusBadgeSection = {
  margin: "24px 0",
};

const statusBadge = {
  display: "inline-block",
  padding: "12px 16px",
  borderRadius: "8px",
  fontSize: "14px",
  fontWeight: "600",
  margin: "0 0 16px 0",
};

const approvedMessage = {
  fontSize: "14px",
  lineHeight: "1.6",
  color: "#10b981",
  margin: "0",
};

const rejectionMessage = {
  fontSize: "14px",
  lineHeight: "1.6",
  color: "#dc2626",
  margin: "0",
};

const pendingMessage = {
  fontSize: "14px",
  lineHeight: "1.6",
  color: "#f59e0b",
  margin: "0",
};

const inProgressMessage = {
  fontSize: "14px",
  lineHeight: "1.6",
  color: "#3b82f6",
  margin: "0",
};

const sectionTitle = {
  fontSize: "14px",
  fontWeight: "bold",
  color: "#1f2937",
  margin: "0 0 12px 0",
};

const checksSection = {
  margin: "24px 0",
  padding: "16px",
  backgroundColor: "#f9fafb",
  borderRadius: "8px",
};

const checkName = {
  fontSize: "13px",
  fontWeight: "600",
  color: "#1f2937",
  margin: "0",
};

const failureReason = {
  fontSize: "12px",
  color: "#ef4444",
  margin: "4px 0 0 0",
};

const nextStepsSection = {
  margin: "24px 0",
  padding: "16px",
  backgroundColor: "#f0f9ff",
  borderRadius: "8px",
};

const stepNumber = {
  fontSize: "16px",
  fontWeight: "bold",
  color: "#003d82",
  backgroundColor: "#dbeafe",
  width: "30px",
  height: "30px",
  borderRadius: "50%",
  textAlign: "center" as const,
  lineHeight: "30px",
  margin: "0",
};

const stepText = {
  fontSize: "13px",
  color: "#4b5563",
  margin: "0",
  lineHeight: "1.5",
};

const optionText = {
  fontSize: "13px",
  color: "#4b5563",
  margin: "0",
  lineHeight: "1.5",
};

const paragraph = {
  fontSize: "14px",
  lineHeight: "1.6",
  margin: "0 0 12px 0",
  color: "#4b5563",
};

const ctaSection = {
  textAlign: "center" as const,
  margin: "32px 0",
};

const button = {
  backgroundColor: "#003d82",
  color: "#ffffff",
  padding: "12px 32px",
  borderRadius: "6px",
  fontSize: "14px",
  fontWeight: "bold",
  textDecoration: "none",
  display: "inline-block",
};

const supportLink = {
  color: "#003d82",
  textDecoration: "none",
  fontSize: "13px",
  fontWeight: "600",
};

const benefitsSection = {
  margin: "24px 0",
  padding: "16px",
  backgroundColor: "#f0fdf4",
  borderRadius: "8px",
};

const benefitText = {
  fontSize: "13px",
  color: "#4b5563",
  margin: "0",
  lineHeight: "1.5",
};

const supportSection = {
  margin: "32px 0",
  padding: "16px",
  backgroundColor: "#f3f4f6",
  borderRadius: "8px",
};

const supportTitle = {
  fontSize: "14px",
  fontWeight: "bold",
  color: "#1f2937",
  margin: "0 0 8px 0",
};

const linkStyle = {
  color: "#003d82",
  textDecoration: "underline",
};

const footer = {
  padding: "24px",
  textAlign: "center" as const,
};

const footerText = {
  fontSize: "11px",
  color: "#9ca3af",
  margin: "0",
};

const footerLink = {
  fontSize: "11px",
  color: "#003d82",
  textDecoration: "none",
};

export default VerificationStatus;
