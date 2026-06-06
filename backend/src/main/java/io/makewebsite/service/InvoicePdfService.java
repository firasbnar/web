package io.makewebsite.service;

import com.lowagie.text.*;
import com.lowagie.text.Font;
import com.lowagie.text.pdf.PdfPCell;
import com.lowagie.text.pdf.PdfPTable;
import com.lowagie.text.pdf.PdfWriter;
import io.makewebsite.entity.*;
import io.makewebsite.repository.OrderItemRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.awt.Color;
import java.io.ByteArrayOutputStream;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.net.URL;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
@Slf4j
public class InvoicePdfService {

    private final OrderItemRepository orderItemRepository;

    public byte[] generatePdf(Order order, Boutique boutique, Invoice invoice) {
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        try {
            Document document = new Document(PageSize.A4);
            PdfWriter.getInstance(document, baos);
            document.open();

            addHeader(document, boutique, invoice, order);
            document.add(new Paragraph(" "));
            addCustomerInfo(document, order, invoice);
            document.add(new Paragraph(" "));
            addItemsTable(document, order);
            document.add(new Paragraph(" "));
            addTotals(document, order, boutique);

            document.close();
        } catch (Exception e) {
            log.error("Failed to generate PDF for order {}", order.getOrderNumber(), e);
            throw new RuntimeException("PDF generation failed", e);
        }
        return baos.toByteArray();
    }

    private void addHeader(Document document, Boutique boutique, Invoice invoice, Order order) throws DocumentException {
        Color primary = new Color(39, 16, 191);

        Font titleFont = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 24, primary);
        Font normalFont = FontFactory.getFont(FontFactory.HELVETICA, 10, Color.DARK_GRAY);
        Font invoiceFont = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 16, primary);

        PdfPTable headerTable = new PdfPTable(2);
        headerTable.setWidthPercentage(100);
        headerTable.setWidths(new float[]{1, 1});

        PdfPCell leftCell = new PdfPCell();
        leftCell.setBorder(Rectangle.NO_BORDER);
        leftCell.setPadding(0);

        try {
            if (boutique.getLogoUrl() != null && !boutique.getLogoUrl().isBlank()) {
                String logoUrl = boutique.getLogoUrl();
                if (logoUrl.startsWith("http://") || logoUrl.startsWith("https://")) {
                    Image logo = Image.getInstance(new URL(logoUrl));
                    float maxWidth = 120;
                    float maxHeight = 60;
                    float scale = Math.min(maxWidth / logo.getWidth(), maxHeight / logo.getHeight());
                    if (scale < 1) {
                        logo.scalePercent(scale * 100);
                    }
                    leftCell.addElement(new Chunk(logo, 0, 0));
                }
            }
        } catch (Exception e) {
            log.debug("Could not load logo for PDF: {}", e.getMessage());
        }

        Paragraph boutiqueName = new Paragraph(boutique.getName() != null ? boutique.getName() : "Boutique", titleFont);
        boutiqueName.setSpacingBefore(4);
        boutiqueName.setSpacingAfter(2);
        leftCell.addElement(boutiqueName);

        if (boutique.getEmail() != null && !boutique.getEmail().isBlank()) {
            leftCell.addElement(new Paragraph(boutique.getEmail(), normalFont));
        }
        if (boutique.getPhone() != null && !boutique.getPhone().isBlank()) {
            leftCell.addElement(new Paragraph(boutique.getPhone(), normalFont));
        }
        if (boutique.getAddress() != null && !boutique.getAddress().isBlank()) {
            leftCell.addElement(new Paragraph(boutique.getAddress(), normalFont));
        }

        PdfPCell rightCell = new PdfPCell();
        rightCell.setBorder(Rectangle.NO_BORDER);
        rightCell.setPadding(0);
        rightCell.setHorizontalAlignment(Element.ALIGN_RIGHT);
        rightCell.setVerticalAlignment(Element.ALIGN_TOP);

        Paragraph invoiceTitle = new Paragraph("FACTURE", invoiceFont);
        invoiceTitle.setAlignment(Element.ALIGN_RIGHT);
        rightCell.addElement(invoiceTitle);

        Paragraph invNum = new Paragraph(invoice.getInvoiceNumber() != null ? invoice.getInvoiceNumber() : "", normalFont);
        invNum.setAlignment(Element.ALIGN_RIGHT);
        rightCell.addElement(invNum);

        String issuedAt = order.getInvoiceCreatedAt() != null
                ? order.getInvoiceCreatedAt().format(DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm"))
                : LocalDateTime.now().format(DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm"));
        Paragraph datePara = new Paragraph("Date: " + issuedAt, normalFont);
        datePara.setAlignment(Element.ALIGN_RIGHT);
        rightCell.addElement(datePara);

        headerTable.addCell(leftCell);
        headerTable.addCell(rightCell);

        document.add(headerTable);

        PdfPTable line = new PdfPTable(1);
        line.setWidthPercentage(100);
        PdfPCell lineCell = new PdfPCell();
        lineCell.setBorder(Rectangle.BOTTOM);
        lineCell.setBorderColorBottom(primary);
        lineCell.setBorderWidthBottom(3);
        lineCell.setPadding(0);
        lineCell.setFixedHeight(4);
        line.addCell(lineCell);
        document.add(line);
    }

    private void addCustomerInfo(Document document, Order order, Invoice invoice) throws DocumentException {
        Font sectionFont = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 12, new Color(39, 16, 191));
        Font labelFont = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 10, Color.DARK_GRAY);
        Font valueFont = FontFactory.getFont(FontFactory.HELVETICA, 10, new Color(23, 32, 51));

        @SuppressWarnings("unchecked")
        Map<String, Object> invoiceData = invoice.getInvoiceData();
        String customerName = "Client";
        String customerEmail = "";
        String customerPhone = "";
        String shippingAddress = "";

        if (invoiceData != null) {
            Object customerObj = invoiceData.get("customer");
            if (customerObj instanceof Map<?, ?> customerMap) {
                customerName = stringVal(customerMap.get("name"), "Client");
                customerEmail = stringVal(customerMap.get("email"), "");
                customerPhone = stringVal(customerMap.get("phone"), "");
                shippingAddress = stringVal(customerMap.get("shippingAddress"), "");
            }
        }

        PdfPTable grid = new PdfPTable(2);
        grid.setWidthPercentage(100);
        grid.setSpacingBefore(8);

        PdfPCell customerBox = new PdfPCell();
        customerBox.setBorder(Rectangle.BOX);
        customerBox.setBorderColor(new Color(229, 234, 243));
        customerBox.setPadding(12);
        customerBox.setBackgroundColor(new Color(251, 252, 255));

        customerBox.addElement(new Paragraph("Client", sectionFont));
        Paragraph space = new Paragraph(" ");
        space.setLeading(4);
        customerBox.addElement(space);
        customerBox.addElement(new Paragraph(customerName, valueFont));
        if (!customerEmail.isBlank()) {
            customerBox.addElement(new Paragraph(customerEmail, valueFont));
        }
        if (!customerPhone.isBlank()) {
            customerBox.addElement(new Paragraph(customerPhone, valueFont));
        }
        if (!shippingAddress.isBlank()) {
            customerBox.addElement(new Paragraph(shippingAddress, valueFont));
        }

        @SuppressWarnings("unchecked")
        Map<String, Object> boutiqueData = invoiceData != null ? (Map<String, Object>) invoiceData.get("boutique") : null;

        PdfPCell orderBox = new PdfPCell();
        orderBox.setBorder(Rectangle.BOX);
        orderBox.setBorderColor(new Color(229, 234, 243));
        orderBox.setPadding(12);
        orderBox.setBackgroundColor(new Color(251, 252, 255));

        orderBox.addElement(new Paragraph("Commande", sectionFont));
        Paragraph space2 = new Paragraph(" ");
        space2.setLeading(4);
        orderBox.addElement(space2);
        orderBox.addElement(new Paragraph("Num\u00e9ro: " + (order.getOrderNumber() != null ? order.getOrderNumber() : ""), valueFont));
        orderBox.addElement(new Paragraph("Date facture: " + (order.getInvoiceCreatedAt() != null
                ? order.getInvoiceCreatedAt().format(DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm"))
                : ""), valueFont));
        orderBox.addElement(new Paragraph("Paiement: " + (order.getPaymentMethod() != null ? order.getPaymentMethod() : ""), valueFont));
        String paid = "PAID".equalsIgnoreCase(order.getPaymentStatus()) ? "Pay\u00e9e" : "Non pay\u00e9e";
        orderBox.addElement(new Paragraph("Statut: " + paid, valueFont));

        grid.addCell(customerBox);
        grid.addCell(orderBox);
        document.add(grid);
    }

    @SuppressWarnings("unchecked")
    private void addItemsTable(Document document, Order order) throws DocumentException {
        Font tableHeaderFont = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 9, Color.WHITE);
        Font tableFont = FontFactory.getFont(FontFactory.HELVETICA, 9, new Color(23, 32, 51));

        Color headerBg = new Color(39, 16, 191);

        PdfPTable table = new PdfPTable(5);
        table.setWidthPercentage(100);
        table.setWidths(new float[]{0.5f, 3f, 1f, 1.5f, 1.5f});
        table.setHeaderRows(1);

        String[] headers = {"#", "Article", "Qt\u00e9", "P.U", "Total"};
        for (String h : headers) {
            PdfPCell cell = new PdfPCell(new Phrase(h, tableHeaderFont));
            cell.setBackgroundColor(headerBg);
            cell.setPadding(8);
            cell.setHorizontalAlignment(h.equals("#") || h.equals("Qt\u00e9") ? Element.ALIGN_CENTER : Element.ALIGN_LEFT);
            cell.setBorder(Rectangle.NO_BORDER);
            table.addCell(cell);
        }

        List<OrderItem> items = orderItemRepository.findByOrderId(order.getId());
        int idx = 1;
        for (OrderItem item : items) {
            table.addCell(centerCell(String.valueOf(idx++), tableFont));
            table.addCell(leftCell(item.getProductName() != null ? item.getProductName() : "", tableFont));
            table.addCell(centerCell(String.valueOf(item.getQuantity() != null ? item.getQuantity() : 0), tableFont));
            table.addCell(rightCell(formatMoney(item.getUnitPrice()), tableFont));
            table.addCell(rightCell(formatMoney(item.getSubtotal()), tableFont));
        }

        document.add(table);
    }

    private void addTotals(Document document, Order order, Boutique boutique) throws DocumentException {
        Font labelFont = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 10, Color.DARK_GRAY);
        Font valueFont = FontFactory.getFont(FontFactory.HELVETICA, 10, new Color(23, 32, 51));
        Font totalFont = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 14, new Color(39, 16, 191));

        String currency = boutique.getCurrency() != null ? boutique.getCurrency() : "TND";

        PdfPTable totalsTable = new PdfPTable(2);
        totalsTable.setWidthPercentage(50);
        totalsTable.setHorizontalAlignment(Element.ALIGN_RIGHT);
        totalsTable.setSpacingBefore(8);

        addTotalRow(totalsTable, "Sous-total", formatMoney(order.getSubtotal()) + " " + currency, labelFont, valueFont, false);
        addTotalRow(totalsTable, "Livraison", formatMoney(order.getShippingFee()) + " " + currency, labelFont, valueFont, false);

        if (order.getDiscount() != null && order.getDiscount().compareTo(BigDecimal.ZERO) > 0) {
            addTotalRow(totalsTable, "Remise", "-" + formatMoney(order.getDiscount()) + " " + currency, labelFont, valueFont, false);
        }

        PdfPCell spacer = new PdfPCell();
        spacer.setBorder(Rectangle.BOTTOM);
        spacer.setBorderColorBottom(new Color(229, 234, 243));
        spacer.setColspan(2);
        spacer.setFixedHeight(2);
        spacer.setPadding(0);
        totalsTable.addCell(spacer);

        addTotalRow(totalsTable, "Total", formatMoney(order.getTotal()) + " " + currency, totalFont, totalFont, true);

        document.add(totalsTable);
    }

    private void addTotalRow(PdfPTable table, String label, String value,
                              Font labelFont, Font valueFont, boolean isTotal) {
        PdfPCell labelCell = new PdfPCell(new Phrase(label, labelFont));
        labelCell.setBorder(Rectangle.NO_BORDER);
        labelCell.setPadding(6);
        labelCell.setPaddingLeft(0);
        labelCell.setHorizontalAlignment(Element.ALIGN_LEFT);
        if (isTotal) {
            labelCell.setPaddingTop(8);
        }
        table.addCell(labelCell);

        PdfPCell valueCell = new PdfPCell(new Phrase(value, valueFont));
        valueCell.setBorder(Rectangle.NO_BORDER);
        valueCell.setPadding(6);
        valueCell.setPaddingRight(0);
        valueCell.setHorizontalAlignment(Element.ALIGN_RIGHT);
        if (isTotal) {
            valueCell.setPaddingTop(8);
        }
        table.addCell(valueCell);
    }

    private void addFooter(Document document) throws DocumentException {
        Font footerFont = FontFactory.getFont(FontFactory.HELVETICA, 8, Color.LIGHT_GRAY);
        Paragraph footer = new Paragraph("G\u00e9n\u00e9r\u00e9 par MakeWebsite.io", footerFont);
        footer.setAlignment(Element.ALIGN_CENTER);
        footer.setSpacingBefore(20);
        document.add(footer);
    }

    private PdfPCell centerCell(String text, Font font) {
        PdfPCell cell = new PdfPCell(new Phrase(text, font));
        cell.setPadding(8);
        cell.setHorizontalAlignment(Element.ALIGN_CENTER);
        cell.setBorder(Rectangle.NO_BORDER);
        return cell;
    }

    private PdfPCell leftCell(String text, Font font) {
        PdfPCell cell = new PdfPCell(new Phrase(text, font));
        cell.setPadding(8);
        cell.setHorizontalAlignment(Element.ALIGN_LEFT);
        cell.setBorder(Rectangle.NO_BORDER);
        return cell;
    }

    private PdfPCell rightCell(String text, Font font) {
        PdfPCell cell = new PdfPCell(new Phrase(text, font));
        cell.setPadding(8);
        cell.setHorizontalAlignment(Element.ALIGN_RIGHT);
        cell.setBorder(Rectangle.NO_BORDER);
        return cell;
    }

    private String formatMoney(BigDecimal value) {
        if (value == null) return "0.000";
        return value.setScale(3, RoundingMode.HALF_UP).toPlainString();
    }

    private String stringVal(Object obj, String defaultValue) {
        return obj != null ? obj.toString() : defaultValue;
    }
}
