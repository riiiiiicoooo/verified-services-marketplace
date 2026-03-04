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

interface BookingConfirmationProps {
  customerName: string;
  providerName: string;
  jobTitle: string;
  jobDescription: string;
  bidAmount: number;
  scheduledDate: string;
  scheduledTime: string;
  location: string;
  providerPhone: string;
  providerEmail: string;
  providerImageUrl?: string;
  dashboardLink: string;
  estimatedDuration?: string;
}

const baseUrl = process.env.NEXT_PUBLIC_BASE_URL || "https://marketplace.example.com";

export const BookingConfirmation: React.FC<BookingConfirmationProps> = ({
  customerName,
  providerName,
  jobTitle,
  jobDescription,
  bidAmount,
  scheduledDate,
  scheduledTime,
  location,
  providerPhone,
  providerEmail,
  providerImageUrl,
  dashboardLink,
  estimatedDuration,
}) => (
  <Html>
    <Head />
    <Preview>Booking confirmed with {providerName} for {jobTitle}</Preview>
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
          <Text style={headerTitle}>Booking Confirmed!</Text>
        </Section>

        {/* Main content */}
        <Section style={content}>
          <Text style={greeting}>Hi {customerName},</Text>

          <Text style={paragraph}>
            Your booking with <strong>{providerName}</strong> is confirmed.
            Here's what's next:
          </Text>

          {/* Service details card */}
          <Section style={detailsCard}>
            <Text style={detailsTitle}>{jobTitle}</Text>

            <Row style={{ marginBottom: "16px" }}>
              <Column style={{ width: "50%" }}>
                <Text style={detailLabel}>Scheduled Date</Text>
                <Text style={detailValue}>{scheduledDate}</Text>
              </Column>
              <Column style={{ textAlign: "right" as const }}>
                <Text style={detailLabel}>Time</Text>
                <Text style={detailValue}>{scheduledTime}</Text>
              </Column>
            </Row>

            <Row style={{ marginBottom: "16px" }}>
              <Column style={{ width: "50%" }}>
                <Text style={detailLabel}>Location</Text>
                <Text style={detailValue}>{location}</Text>
              </Column>
              <Column style={{ textAlign: "right" as const }}>
                <Text style={detailLabel}>Price</Text>
                <Text style={detailValue}>${bidAmount.toFixed(2)}</Text>
              </Column>
            </Row>

            {estimatedDuration && (
              <Row>
                <Column>
                  <Text style={detailLabel}>Estimated Duration</Text>
                  <Text style={detailValue}>{estimatedDuration}</Text>
                </Column>
              </Row>
            )}

            <Hr style={{ margin: "16px 0" }} />

            <Text style={description}>{jobDescription}</Text>
          </Section>

          {/* Provider contact */}
          <Section style={providerSection}>
            <Text style={sectionTitle}>Your Service Provider</Text>

            <Row>
              {providerImageUrl && (
                <Column style={{ paddingRight: "16px", width: "20%" }}>
                  <Img
                    src={providerImageUrl}
                    width="60"
                    height="60"
                    style={providerImage}
                    alt={providerName}
                  />
                </Column>
              )}
              <Column>
                <Text style={providerName_}>
                  <strong>{providerName}</strong>
                </Text>
                <Link href={`tel:${providerPhone}`} style={contactLink}>
                  {providerPhone}
                </Link>
                <Text style={{ margin: "4px 0" }} />
                <Link href={`mailto:${providerEmail}`} style={contactLink}>
                  {providerEmail}
                </Link>
              </Column>
            </Row>

            <Text style={contactNote}>
              You can contact your provider directly to discuss any details
              before the scheduled date.
            </Text>
          </Section>

          {/* Payment info */}
          <Section style={paymentSection}>
            <Text style={sectionTitle}>Payment Details</Text>

            <Row style={{ marginBottom: "12px" }}>
              <Column style={{ width: "60%" }}>
                <Text style={paymentLabel}>Bid Amount</Text>
              </Column>
              <Column style={{ textAlign: "right" as const }}>
                <Text style={paymentValue}>${bidAmount.toFixed(2)}</Text>
              </Column>
            </Row>

            <Row style={{ marginBottom: "12px" }}>
              <Column style={{ width: "60%" }}>
                <Text style={paymentLabel}>Payment Status</Text>
              </Column>
              <Column style={{ textAlign: "right" as const }}>
                <Text style={{ ...paymentValue, color: "#10b981" }}>
                  Held in Escrow
                </Text>
              </Column>
            </Row>

            <Hr style={{ margin: "12px 0" }} />

            <Text style={escrowNote}>
              Your payment is securely held in escrow until the job is
              complete. The funds are released to your provider once you
              confirm satisfaction.
            </Text>
          </Section>

          {/* CTA */}
          <Section style={ctaSection}>
            <Button style={button} href={dashboardLink}>
              View Booking Details
            </Button>
          </Section>

          {/* What happens next */}
          <Section style={timelineSection}>
            <Text style={sectionTitle}>What Happens Next</Text>

            <Row style={{ marginBottom: "16px" }}>
              <Column style={{ width: "40px", paddingRight: "12px" }}>
                <Text style={timelineNumber}>1</Text>
              </Column>
              <Column>
                <Text style={timelineText}>
                  <strong>Before the scheduled date:</strong> Your provider may
                  reach out to confirm details or ask questions.
                </Text>
              </Column>
            </Row>

            <Row style={{ marginBottom: "16px" }}>
              <Column style={{ width: "40px", paddingRight: "12px" }}>
                <Text style={timelineNumber}>2</Text>
              </Column>
              <Column>
                <Text style={timelineText}>
                  <strong>On the scheduled date:</strong> Your provider will
                  arrive at the agreed time to start the work.
                </Text>
              </Column>
            </Row>

            <Row style={{ marginBottom: "16px" }}>
              <Column style={{ width: "40px", paddingRight: "12px" }}>
                <Text style={timelineNumber}>3</Text>
              </Column>
              <Column>
                <Text style={timelineText}>
                  <strong>Upon completion:</strong> Mark the job as complete
                  and review your provider's work.
                </Text>
              </Column>
            </Row>

            <Row>
              <Column style={{ width: "40px", paddingRight: "12px" }}>
                <Text style={timelineNumber}>4</Text>
              </Column>
              <Column>
                <Text style={timelineText}>
                  <strong>Leave a review:</strong> Share your feedback to help
                  other customers and build the provider's reputation.
                </Text>
              </Column>
            </Row>
          </Section>

          {/* Support info */}
          <Section style={supportSection}>
            <Text style={supportTitle}>Need Help?</Text>
            <Text style={paragraph}>
              If you have any questions or concerns about your booking, please
              don't hesitate to contact our support team.
            </Text>
            <Button style={{ ...button, backgroundColor: "#f3f4f6" }} href={`${baseUrl}/support`}>
              Contact Support
            </Button>
          </Section>
        </Section>

        {/* Footer */}
        <Hr style={{ margin: "32px 0" }} />
        <Section style={footer}>
          <Row>
            <Column>
              <Text style={footerText}>
                © 2026 Verified Services Marketplace. All rights reserved.
              </Text>
            </Column>
          </Row>
          <Row>
            <Column style={{ textAlign: "center" as const }}>
              <Link href={`${baseUrl}`} style={footerLink}>
                Home
              </Link>
              <Text style={{ margin: "0 8px", display: "inline" }}>•</Text>
              <Link href={`${baseUrl}/help`} style={footerLink}>
                Help
              </Link>
              <Text style={{ margin: "0 8px", display: "inline" }}>•</Text>
              <Link href={`${baseUrl}/privacy`} style={footerLink}>
                Privacy
              </Link>
              <Text style={{ margin: "0 8px", display: "inline" }}>•</Text>
              <Link href={`${baseUrl}/terms`} style={footerLink}>
                Terms
              </Link>
            </Column>
          </Row>
        </Section>
      </Container>
    </Body>
  </Html>
);

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

const paragraph = {
  fontSize: "14px",
  lineHeight: "1.6",
  margin: "0 0 16px 0",
  color: "#4b5563",
};

const detailsCard = {
  backgroundColor: "#f3f4f6",
  borderRadius: "8px",
  padding: "16px",
  margin: "24px 0",
};

const detailsTitle = {
  fontSize: "16px",
  fontWeight: "bold",
  color: "#1f2937",
  margin: "0 0 16px 0",
};

const detailLabel = {
  fontSize: "12px",
  fontWeight: "600",
  color: "#6b7280",
  margin: "0",
  textTransform: "uppercase" as const,
};

const detailValue = {
  fontSize: "14px",
  fontWeight: "500",
  color: "#1f2937",
  margin: "4px 0 0 0",
};

const description = {
  fontSize: "13px",
  color: "#4b5563",
  margin: "0",
  fontStyle: "italic",
};

const providerSection = {
  margin: "24px 0",
  padding: "16px",
  backgroundColor: "#f0f9ff",
  borderRadius: "8px",
};

const sectionTitle = {
  fontSize: "14px",
  fontWeight: "bold",
  color: "#1f2937",
  margin: "0 0 12px 0",
};

const providerImage = {
  borderRadius: "50%",
  width: "60px",
  height: "60px",
};

const providerName_ = {
  fontSize: "14px",
  margin: "0 0 4px 0",
  color: "#1f2937",
};

const contactLink = {
  color: "#003d82",
  textDecoration: "none",
  fontSize: "13px",
};

const contactNote = {
  fontSize: "12px",
  color: "#6b7280",
  margin: "12px 0 0 0",
  fontStyle: "italic",
};

const paymentSection = {
  margin: "24px 0",
  padding: "16px",
  backgroundColor: "#f9fce4",
  borderRadius: "8px",
};

const paymentLabel = {
  fontSize: "13px",
  color: "#4b5563",
  margin: "0",
};

const paymentValue = {
  fontSize: "14px",
  fontWeight: "600",
  color: "#1f2937",
  margin: "0",
};

const escrowNote = {
  fontSize: "12px",
  color: "#6b7280",
  margin: "0",
  fontStyle: "italic",
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

const timelineSection = {
  margin: "24px 0",
};

const timelineNumber = {
  fontSize: "18px",
  fontWeight: "bold",
  color: "#003d82",
  backgroundColor: "#dbeafe",
  width: "40px",
  height: "40px",
  borderRadius: "50%",
  textAlign: "center" as const,
  lineHeight: "40px",
};

const timelineText = {
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
  textAlign: "center" as const,
};

const supportTitle = {
  fontSize: "14px",
  fontWeight: "bold",
  color: "#1f2937",
  margin: "0 0 8px 0",
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

export default BookingConfirmation;
