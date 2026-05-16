package io.makewebsite.service;

import jakarta.mail.MessagingException;
import jakarta.mail.internet.InternetAddress;
import jakarta.mail.internet.MimeMessage;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.MailAuthenticationException;
import org.springframework.mail.MailException;
import org.springframework.mail.MailSendException;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Service;

import java.io.UnsupportedEncodingException;

@Service
@RequiredArgsConstructor
@Slf4j
public class EmailService {

    private final JavaMailSender mailSender;

    @Value("${app.public-url:https://scraggly-unmasked-glutinous.ngrok-free.app}")
    private String publicUrl;

    @Value("${spring.mail.username:noreply@makewebsite.io}")
    private String fromAddress;

    @Value("${app.mail.from-name:MakeWebsite}")
    private String fromName;

    public void sendVerificationEmail(String to, String token) {
        try {
            InternetAddress from = internetAddress(fromAddress, fromName);
            InternetAddress recipient = internetAddress(to);
            String link = publicUrl + "/api/auth/verify?token=" + token;

            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");
            helper.setFrom(from);
            helper.setTo(recipient);
            helper.setSubject("Verify your email - MakeWebsite");
            helper.setText(buildVerificationPlainText(link), buildVerificationHtml(link));

            log.info("Sending verification email via SMTP: from={}, to={}, subject={}",
                    from.getAddress(), recipient.getAddress(), message.getSubject());
            mailSender.send(message);
            log.info("EMAIL SENT SUCCESSFULLY TO {} messageId={}", recipient.getAddress(), message.getMessageID());
        } catch (MailAuthenticationException e) {
            log.error("SMTP EMAIL FAILED - Gmail authentication rejected the username/app password.", e);
            throw new EmailDeliveryException("SMTP FAILED: Gmail authentication failed. Use a valid Gmail App Password.", e);
        } catch (MailSendException e) {
            log.error("SMTP EMAIL FAILED - Gmail rejected or could not deliver the message. failedMessages={}, messageExceptions={}",
                    e.getFailedMessages().size(), e.getMessageExceptions(), e);
            throw new EmailDeliveryException("SMTP FAILED: " + rootMessage(e), e);
        } catch (MailException | MessagingException | UnsupportedEncodingException e) {
            log.error("SMTP EMAIL FAILED", e);
            throw new EmailDeliveryException("SMTP FAILED: " + rootMessage(e), e);
        } catch (Exception e) {
            log.error("SMTP EMAIL FAILED", e);
            throw new EmailDeliveryException("SMTP FAILED: " + rootMessage(e), e);
        }
    }

    private InternetAddress internetAddress(String address) throws MessagingException {
        InternetAddress internetAddress = new InternetAddress(address, true);
        internetAddress.validate();
        return internetAddress;
    }

    private InternetAddress internetAddress(String address, String personalName)
            throws MessagingException, UnsupportedEncodingException {
        InternetAddress internetAddress = new InternetAddress(address, personalName, "UTF-8");
        internetAddress.validate();
        return internetAddress;
    }

    private String rootMessage(Throwable throwable) {
        Throwable current = throwable;
        while (current.getCause() != null) {
            current = current.getCause();
        }
        String message = current.getMessage();
        if (message != null && !message.isBlank()) {
            return message;
        }
        return current.getClass().getName();
    }

    private String buildVerificationPlainText(String link) {
        return """
            Verify your email

            Hello,

            To activate your MakeWebsite account, open this verification link:

            %s

            This link expires in 24 hours.

            If you did not create a MakeWebsite account, ignore this email.

            ---
            MakeWebsite
            """.formatted(link);
    }

    private String buildVerificationHtml(String link) {
        String html = """
            <!DOCTYPE html>
            <html>
            <head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"></head>
            <body style="margin:0;padding:0;background-color:#f4f6f9;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif">
            <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f6f9;padding:40px 16px">
            <tr><td align="center">
            <table width="480" cellpadding="0" cellspacing="0" style="background-color:#ffffff;border-radius:8px;overflow:hidden;box-shadow:0 2px 12px rgba(0,0,0,0.08)">
            <tr><td style="padding:36px 32px 22px;text-align:center;background:#2563eb">
            <h1 style="margin:0;color:#ffffff;font-size:22px;font-weight:700">Verify your email</h1>
            <p style="margin:8px 0 0;color:rgba(255,255,255,0.88);font-size:14px;line-height:1.5">Thanks for signing up for MakeWebsite.</p>
            </td></tr>
            <tr><td style="padding:32px 32px 24px">
            <p style="margin:0 0 16px;color:#374151;font-size:14px;line-height:1.6">Hello,</p>
            <p style="margin:0 0 16px;color:#374151;font-size:14px;line-height:1.6">To activate your account, confirm your email address using the button below.</p>
            <table width="100%" cellpadding="0" cellspacing="0"><tr><td align="center" style="padding:8px 0 24px">
            <a href="{{VERIFICATION_URL}}" style="display:inline-block;padding:14px 36px;background:#2563eb;color:#ffffff;text-decoration:none;border-radius:6px;font-size:15px;font-weight:600">Verify email</a>
            </td></tr></table>
            <p style="margin:0 0 16px;color:#6b7280;font-size:13px;line-height:1.5">If the button does not work, copy and paste this link into your browser:</p>
            <p style="margin:0 0 16px;padding:12px;background-color:#f9fafb;border-radius:8px;border:1px solid #e5e7eb;word-break:break-all;font-size:12px;color:#6b7280">{{VERIFICATION_URL}}</p>
            <p style="margin:0 0 8px;color:#6b7280;font-size:12px;line-height:1.5">This link expires in <strong>24 hours</strong>.</p>
            <hr style="border:none;border-top:1px solid #e5e7eb;margin:24px 0">
            <p style="margin:0;color:#9ca3af;font-size:11px;line-height:1.5">If you did not create a MakeWebsite account, ignore this email.</p>
            </td></tr>
            <tr><td style="padding:16px 32px;background-color:#f9fafb;text-align:center">
            <p style="margin:0;color:#9ca3af;font-size:11px">&copy; 2026 MakeWebsite. All rights reserved.</p>
            </td></tr>
            </table>
            </td></tr>
            </table>
            </body>
            </html>
            """;
        return html.replace("{{VERIFICATION_URL}}", link);
    }

    public static class EmailDeliveryException extends RuntimeException {
        public EmailDeliveryException(String message, Throwable cause) {
            super(message, cause);
        }
    }
}
