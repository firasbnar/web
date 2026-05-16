package io.makewebsite.service;

import io.makewebsite.dto.response.SessionResponse;
import io.makewebsite.entity.User;
import io.makewebsite.entity.UserSession;
import io.makewebsite.repository.UserRepository;
import io.makewebsite.repository.UserSessionRepository;
import io.makewebsite.security.JwtUtil;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class SecurityService {
    private final UserSessionRepository sessionRepository;
    private final UserRepository userRepository;
    private final JwtUtil jwtUtil;

    public List<SessionResponse> getActiveSessions(UUID userId) {
        return sessionRepository.findByUserIdAndIsActiveTrueOrderByLastActivityDesc(userId).stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());
    }

    @Transactional
    public void revokeSession(UUID sessionId, UUID userId) {
        UserSession session = sessionRepository.findById(sessionId)
                .orElseThrow(() -> new RuntimeException("Session non trouvée"));
        if (!session.getUser().getId().equals(userId)) {
            throw new RuntimeException("Accès refusé");
        }
        session.setIsActive(false);
        sessionRepository.save(session);
    }

    @Transactional
    public void revokeOtherSessions(UUID userId, String currentTokenHash) {
        sessionRepository.findByUserIdAndIsActiveTrueOrderByLastActivityDesc(userId)
                .forEach(s -> {
                    if (!s.getTokenHash().equals(currentTokenHash)) {
                        s.setIsActive(false);
                        sessionRepository.save(s);
                    }
                });
    }

    @Transactional
    public void deleteAccount(UUID userId) {
        sessionRepository.deactivateAllUserSessions(userId);
        userRepository.deleteById(userId);
    }

    private SessionResponse mapToResponse(UserSession s) {
        return SessionResponse.builder()
                .id(s.getId())
                .deviceInfo(s.getDeviceInfo())
                .ipAddress(s.getIpAddress())
                .isActive(s.getIsActive())
                .lastActivity(s.getLastActivity())
                .createdAt(s.getCreatedAt())
                .build();
    }
}
