package io.makewebsite.security;

import io.makewebsite.entity.User;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

public class UserPrincipal implements UserDetails {

    private final UUID id;
    private final String email;
    private final String password;
    private final String role;
    private final UUID tenantId;
    private String tokenHash;

    public UserPrincipal(UUID id, String email, String password, String role, UUID tenantId) {
        this.id = id;
        this.email = email;
        this.password = password;
        this.role = role;
        this.tenantId = tenantId;
    }

    public UserPrincipal(UUID id, String email, String password, String role, UUID tenantId, String tokenHash) {
        this(id, email, password, role, tenantId);
        this.tokenHash = tokenHash;
    }

    public UUID getUserId() {
        return id;
    }

    public String getEmail() {
        return email;
    }

    public String getRole() {
        return role;
    }

    public UUID getTenantId() {
        return tenantId;
    }

    public String getTokenHash() {
        return tokenHash;
    }

    public void setTokenHash(String tokenHash) {
        this.tokenHash = tokenHash;
    }

    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return List.of(new SimpleGrantedAuthority("ROLE_" + role));
    }

    @Override
    public String getPassword() {
        return password;
    }

    @Override
    public String getUsername() {
        return id.toString();
    }

    @Override
    public boolean isAccountNonExpired() {
        return true;
    }

    @Override
    public boolean isAccountNonLocked() {
        return true;
    }

    @Override
    public boolean isCredentialsNonExpired() {
        return true;
    }

    @Override
    public boolean isEnabled() {
        return true;
    }
}
