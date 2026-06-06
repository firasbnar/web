package io.makewebsite.service;

import io.makewebsite.dto.request.CreateCustomerRequest;
import io.makewebsite.dto.response.CustomerResponse;
import io.makewebsite.entity.*;
import io.makewebsite.repository.*;
import io.makewebsite.util.CsvUtil;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Optional;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class CustomerService {
    private final CustomerRepository customerRepository;
    private final BoutiqueRepository boutiqueRepository;
    private final TelegramNotificationService telegramNotificationService;

    public Page<CustomerResponse> getCustomers(UUID boutiqueId, String search, Pageable pageable) {
        Page<Customer> customers;
        if (search != null && !search.isEmpty()) {
            customers = customerRepository.findByBoutiqueIdAndFullNameContainingIgnoreCase(boutiqueId, search, pageable);
        } else {
            customers = customerRepository.findByBoutiqueId(boutiqueId, pageable);
        }
        return customers.map(this::mapToResponse);
    }

    public CustomerResponse getCustomer(UUID id) {
        Customer customer = customerRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Client non trouvé"));
        return mapToResponse(customer);
    }

    @Transactional
    public CustomerResponse createCustomer(CreateCustomerRequest request) {
        Boutique boutique = boutiqueRepository.findById(request.getBoutiqueId())
                .orElseThrow(() -> new RuntimeException("Boutique non trouvée"));
        Customer customer = Customer.builder()
                .boutique(boutique)
                .fullName(request.getFullName())
                .email(request.getEmail())
                .phone(request.getPhone())
                .address(request.getAddress())
                .city(request.getCity())
                .governorate(request.getGovernorate())
                .postalCode(request.getPostalCode())
                .country(request.getCountry())
                .notes(request.getNotes())
                .build();
        customer = customerRepository.save(customer);
        telegramNotificationService.notifyNewCustomer(customer);
        return mapToResponse(customer);
    }

    @Transactional
    public CustomerResponse updateCustomer(UUID id, CreateCustomerRequest request) {
        Customer customer = customerRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Client non trouvé"));
        if (request.getFullName() != null) customer.setFullName(request.getFullName());
        if (request.getEmail() != null) customer.setEmail(request.getEmail());
        if (request.getPhone() != null) customer.setPhone(request.getPhone());
        if (request.getAddress() != null) customer.setAddress(request.getAddress());
        if (request.getCity() != null) customer.setCity(request.getCity());
        if (request.getGovernorate() != null) customer.setGovernorate(request.getGovernorate());
        if (request.getPostalCode() != null) customer.setPostalCode(request.getPostalCode());
        if (request.getCountry() != null) customer.setCountry(request.getCountry());
        if (request.getNotes() != null) customer.setNotes(request.getNotes());
        customer = customerRepository.save(customer);
        return mapToResponse(customer);
    }

    @Transactional
    public void deleteCustomer(UUID id) {
        customerRepository.deleteById(id);
    }

    @Transactional
    public Customer findOrCreateCustomer(UUID boutiqueId, String fullName, String email,
                                           String phone, String address, String city,
                                           String governorate, String postalCode, String country) {
        Boutique boutique = boutiqueRepository.getReferenceById(boutiqueId);

        // Try phone match first
        if (phone != null && !phone.isEmpty()) {
            Optional<Customer> byPhone = customerRepository.findByBoutiqueIdAndPhone(boutiqueId, phone);
            if (byPhone.isPresent()) {
                Customer c = byPhone.get();
                if (fullName != null) c.setFullName(fullName);
                if (email != null) c.setEmail(email);
                if (address != null) c.setAddress(address);
                if (city != null) c.setCity(city);
                if (governorate != null) c.setGovernorate(governorate);
                if (postalCode != null) c.setPostalCode(postalCode);
                if (country != null) c.setCountry(country);
                return customerRepository.save(c);
            }
        }

        // Fallback to email match
        if (email != null && !email.isEmpty()) {
            Optional<Customer> byEmail = customerRepository.findByBoutiqueIdAndEmail(boutiqueId, email);
            if (byEmail.isPresent()) {
                Customer c = byEmail.get();
                if (fullName != null) c.setFullName(fullName);
                if (phone != null) c.setPhone(phone);
                if (address != null) c.setAddress(address);
                if (city != null) c.setCity(city);
                if (governorate != null) c.setGovernorate(governorate);
                if (postalCode != null) c.setPostalCode(postalCode);
                if (country != null) c.setCountry(country);
                return customerRepository.save(c);
            }
        }

        Customer customer = Customer.builder()
                .boutique(boutique)
                .fullName(fullName != null ? fullName : "Client")
                .email(email)
                .phone(phone)
                .address(address)
                .city(city)
                .governorate(governorate)
                .postalCode(postalCode)
                .country(country)
                .totalOrders(0)
                .totalSpent(BigDecimal.ZERO)
                .build();
        customer = customerRepository.save(customer);
        telegramNotificationService.notifyNewCustomer(customer);
        return customer;
    }

    @Transactional
    public void updateCustomerAggregation(Customer customer, BigDecimal orderTotal) {
        customer.setTotalOrders(customer.getTotalOrders() + 1);
        customer.setTotalSpent(customer.getTotalSpent() != null
                ? customer.getTotalSpent().add(orderTotal)
                : orderTotal);
        customer.setLastOrderDate(LocalDateTime.now());
        customerRepository.save(customer);
    }

    @Transactional(readOnly = true)
    public String exportCsv(UUID boutiqueId) {
        Page<Customer> customers = customerRepository.findByBoutiqueId(boutiqueId, Pageable.unpaged());
        StringBuilder sb = new StringBuilder("\uFEFF");
        sb.append(
            "Nom,Email,T\u00e9l\u00e9phone,Adresse,Ville,Gouvernorat,Code Postal,Pays,Commandes,Total D\u00e9pens\u00e9,Derni\u00e8re Commande,Date Cr\u00e9ation\n"
        );
        for (Customer c : customers) {
            sb.append(CsvUtil.escapeCsv(c.getFullName())).append(",")
              .append(CsvUtil.escapeCsv(c.getEmail())).append(",")
              .append(CsvUtil.escapeCsv(c.getPhone())).append(",")
              .append(CsvUtil.escapeCsv(c.getAddress())).append(",")
              .append(CsvUtil.escapeCsv(c.getCity())).append(",")
              .append(CsvUtil.escapeCsv(c.getGovernorate())).append(",")
              .append(CsvUtil.escapeCsv(c.getPostalCode())).append(",")
              .append(CsvUtil.escapeCsv(c.getCountry())).append(",")
              .append(c.getTotalOrders()).append(",")
              .append(c.getTotalSpent() != null ? c.getTotalSpent() : "0").append(",")
              .append(c.getLastOrderDate() != null ? c.getLastOrderDate().toString() : "").append(",")
              .append(c.getCreatedAt() != null ? c.getCreatedAt().toString() : "").append("\n");
        }
        return sb.toString();
    }

    private CustomerResponse mapToResponse(Customer c) {
        return CustomerResponse.builder()
                .id(c.getId())
                .boutiqueId(c.getBoutique().getId())
                .fullName(c.getFullName())
                .email(c.getEmail())
                .phone(c.getPhone())
                .address(c.getAddress())
                .city(c.getCity())
                .governorate(c.getGovernorate())
                .postalCode(c.getPostalCode())
                .country(c.getCountry())
                .notes(c.getNotes())
                .totalOrders(c.getTotalOrders())
                .totalSpent(c.getTotalSpent() != null ? c.getTotalSpent() : BigDecimal.ZERO)
                .lastOrderDate(c.getLastOrderDate())
                .createdAt(c.getCreatedAt())
                .updatedAt(c.getUpdatedAt())
                .build();
    }
}
