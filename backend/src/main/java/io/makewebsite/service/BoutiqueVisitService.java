package io.makewebsite.service;

import io.makewebsite.entity.StoreView;
import io.makewebsite.repository.StoreViewRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.LocalDateTime;
import java.util.Optional;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class BoutiqueVisitService {

    private final StoreViewRepository storeViewRepository;

    private String hashIp(String ip) {
        if (ip == null) return "unknown";
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] hash = md.digest(ip.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte b : hash) sb.append(String.format("%02x", b));
            return sb.toString().substring(0, 32);
        } catch (NoSuchAlgorithmException e) {
            return ip;
        }
    }

    private boolean hasRecentVisit(UUID boutiqueId, String visitorId, String ipHash) {
        LocalDateTime thirtyMinAgo = LocalDateTime.now().minusMinutes(30);
        if (visitorId != null && !visitorId.isEmpty()) {
            Optional<StoreView> existing = storeViewRepository
                    .findFirstByBoutiqueIdAndVisitorIdAndViewedAtAfter(boutiqueId, visitorId, thirtyMinAgo);
            if (existing.isPresent()) {
                log.debug("Duplicate visit by visitorId={} for boutiqueId={} within 30min, skipping", visitorId, boutiqueId);
                return true;
            }
        }
        Optional<StoreView> existing = storeViewRepository
                .findFirstByBoutiqueIdAndIpHashAndViewedAtAfter(boutiqueId, ipHash, thirtyMinAgo);
        if (existing.isPresent()) {
            log.debug("Duplicate visit by ipHash={} for boutiqueId={} within 30min, skipping", ipHash, boutiqueId);
            return true;
        }
        return false;
    }

    @Transactional
    public void recordVisit(UUID boutiqueId, String slug, String ipAddress, String userAgent, String visitorId) {
        String ipHash = hashIp(ipAddress);
        if (hasRecentVisit(boutiqueId, visitorId, ipHash)) return;

        StoreView view = StoreView.builder()
                .boutiqueId(boutiqueId)
                .page("/store/" + slug)
                .ipHash(ipHash)
                .visitorId(visitorId)
                .userAgent(userAgent)
                .viewedAt(LocalDateTime.now())
                .build();
        storeViewRepository.save(view);
        log.info("Visit recorded for boutiqueId={} slug={} visitorId={} ipHash={}", boutiqueId, slug, visitorId, ipHash);
    }
}
