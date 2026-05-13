package io.makewebsite.service;

import io.makewebsite.dto.request.CreateCustomerRequest;
import io.makewebsite.dto.response.CustomerResponse;
import io.makewebsite.entity.*;
import io.makewebsite.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class CustomerService {
    private final CustomerRepository customerRepository;
    private final BoutiqueRepository boutiqueRepository;

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
        Customer customer = customerRepository.findById(id).orElseThrow(() -> new RuntimeException("Client non trouvé"));
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
                .notes(request.getNotes())
                .build();
        customer = customerRepository.save(customer);
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
        if (request.getNotes() != null) customer.setNotes(request.getNotes());
        customer = customerRepository.save(customer);
        return mapToResponse(customer);
    }

    @Transactional
    public void deleteCustomer(UUID id) {
        customerRepository.deleteById(id);
    }

    private CustomerResponse mapToResponse(Customer c) {
        long totalOrders = customerRepository.countByCustomerId(c.getId());
        Double totalSpent = customerRepository.sumTotalByCustomerId(c.getId());
        java.time.LocalDateTime lastOrderDate = customerRepository.findLastOrderDateByCustomerId(c.getId());
        return CustomerResponse.builder()
                .id(c.getId()).boutiqueId(c.getBoutique().getId())
                .fullName(c.getFullName()).email(c.getEmail())
                .phone(c.getPhone()).address(c.getAddress())
                .city(c.getCity()).governorate(c.getGovernorate())
                .notes(c.getNotes()).createdAt(c.getCreatedAt())
                .totalOrders(totalOrders)
                .totalSpent(totalSpent != null ? totalSpent : 0.0)
                .lastOrderDate(lastOrderDate)
                .build();
    }
}
