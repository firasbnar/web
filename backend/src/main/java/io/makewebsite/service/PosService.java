package io.makewebsite.service;

import io.makewebsite.dto.request.*;
import io.makewebsite.dto.response.*;
import io.makewebsite.entity.*;
import io.makewebsite.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class PosService {
    private final PosSessionRepository posSessionRepository;
    private final PosTransactionRepository posTransactionRepository;
    private final BoutiqueRepository boutiqueRepository;
    private final OrderService orderService;
    private final UserRepository userRepository;
    private final CaisseService caisseService;

    @Transactional
    public PosSessionResponse openSession(OpenPosSessionRequest request, UUID userId) {
        posSessionRepository.findByBoutiqueIdAndClosedAtIsNull(request.getBoutiqueId())
                .ifPresent(s -> { throw new RuntimeException("Une session est déjà ouverte"); });

        Boutique boutique = boutiqueRepository.findById(request.getBoutiqueId())
                .orElseThrow(() -> new RuntimeException("Boutique non trouvée"));
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("Utilisateur non trouvé"));

        PosSession session = PosSession.builder()
                .boutique(boutique)
                .user(user)
                .openedAt(LocalDateTime.now())
                .openingCash(request.getOpeningCash() != null ? request.getOpeningCash() : BigDecimal.ZERO)
                .totalSales(BigDecimal.ZERO)
                .build();
        session = posSessionRepository.save(session);

        try {
            caisseService.recordActivity(request.getBoutiqueId(), userId, user.getFullName(),
                    "OUVERTURE_CAISSE", "SUCCESS",
                    "Caisse ouverte avec " + request.getOpeningCash() + " TND", null, null);
        } catch (Exception e) {
            // non-blocking
        }

        return mapToResponse(session);
    }

    @Transactional
    public PosSessionResponse closeSession(UUID id, ClosePosSessionRequest request) {
        PosSession session = posSessionRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Session non trouvée"));
        session.setClosedAt(LocalDateTime.now());
        session.setClosingCash(request.getClosingCash());
        session = posSessionRepository.save(session);

        try {
            caisseService.recordActivity(session.getBoutique().getId(), session.getUser().getId(),
                    session.getUser().getFullName(), "FERMETURE_CAISSE", "SUCCESS",
                    "Caisse fermée avec " + request.getClosingCash() + " TND", null, null);
        } catch (Exception e) {
            // non-blocking
        }

        return mapToResponse(session);
    }

    public PosSessionResponse getActiveSession(UUID boutiqueId) {
        PosSession session = posSessionRepository.findByBoutiqueIdAndClosedAtIsNull(boutiqueId)
                .orElseThrow(() -> new RuntimeException("Aucune session active"));
        return mapToResponse(session);
    }

    public PosSessionResponse getSessionSummary(UUID id) {
        PosSession session = posSessionRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Session non trouvée"));
        return mapToResponse(session);
    }

    @Transactional
    public PosTransactionResponse createTransaction(CreatePosTransactionRequest request) {
        PosSession session = posSessionRepository.findById(request.getSessionId())
                .orElseThrow(() -> new RuntimeException("Session non trouvée"));

        CreateOrderRequest orderReq = CreateOrderRequest.builder()
                .boutiqueId(session.getBoutique().getId())
                .items(request.getItems())
                .paymentMethod(request.getPaymentMethod())
                .shippingFee(BigDecimal.ZERO)
                .discount(BigDecimal.ZERO)
                .build();
        OrderResponse orderResponse = orderService.createOrder(orderReq, session.getUser().getId());

        orderService.updatePayment(UUID.fromString(orderResponse.getId().toString()),
                UpdatePaymentStatusRequest.builder().paymentStatus("PAID").build());

        PosTransaction transaction = PosTransaction.builder()
                .session(session)
                .total(request.getTotal())
                .paymentMethod(request.getPaymentMethod())
                .build();
        transaction = posTransactionRepository.save(transaction);

        session.setTotalSales(session.getTotalSales().add(request.getTotal()));
        posSessionRepository.save(session);

        return PosTransactionResponse.builder()
                .id(transaction.getId())
                .sessionId(session.getId())
                .total(transaction.getTotal())
                .paymentMethod(transaction.getPaymentMethod())
                .createdAt(transaction.getCreatedAt())
                .build();
    }

    private PosSessionResponse mapToResponse(PosSession s) {
        List<PosTransaction> transactions = posTransactionRepository.findBySessionId(s.getId());
        BigDecimal totalTransactions = transactions.stream()
                .map(PosTransaction::getTotal).reduce(BigDecimal.ZERO, BigDecimal::add);
        return PosSessionResponse.builder()
                .id(s.getId()).boutiqueId(s.getBoutique().getId())
                .userId(s.getUser().getId())
                .openedAt(s.getOpenedAt()).closedAt(s.getClosedAt())
                .openingCash(s.getOpeningCash()).closingCash(s.getClosingCash())
                .totalSales(totalTransactions)
                .notes(s.getNotes())
                .build();
    }
}
