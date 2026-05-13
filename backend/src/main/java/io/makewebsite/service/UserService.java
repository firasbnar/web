package io.makewebsite.service;

import io.makewebsite.entity.User;
import io.makewebsite.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class UserService {
    private final UserRepository userRepository;

    @Transactional
    public void setActiveBoutique(UUID userId, UUID boutiqueId) {
        User user = userRepository.findById(userId).orElseThrow(() -> new RuntimeException("User not found"));
        user.setActiveBoutiqueId(boutiqueId);
        userRepository.save(user);
    }
}
