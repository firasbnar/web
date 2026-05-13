package io.makewebsite.service;

import io.makewebsite.dto.request.CreateCategoryRequest;
import io.makewebsite.dto.response.CategoryResponse;
import io.makewebsite.entity.*;
import io.makewebsite.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class CategoryService {
    private final CategoryRepository categoryRepository;
    private final BoutiqueRepository boutiqueRepository;
    private final ProductRepository productRepository;

    public List<CategoryResponse> getCategories(UUID boutiqueId) {
        return categoryRepository.findByBoutiqueIdOrderBySortOrder(boutiqueId).stream()
                .map(this::mapToResponse).collect(Collectors.toList());
    }

    @Transactional
    public CategoryResponse createCategory(CreateCategoryRequest request) {
        Boutique boutique = boutiqueRepository.findById(request.getBoutiqueId())
                .orElseThrow(() -> new RuntimeException("Boutique non trouvée"));
        Category category = Category.builder()
                .boutique(boutique)
                .name(request.getName())
                .slug(request.getSlug())
                .imageUrl(request.getImageUrl())
                .sortOrder(request.getSortOrder() != null ? request.getSortOrder() : 0)
                .build();
        category = categoryRepository.save(category);
        return mapToResponse(category);
    }

    @Transactional
    public CategoryResponse updateCategory(UUID id, CreateCategoryRequest request) {
        Category category = categoryRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Catégorie non trouvée"));
        if (request.getName() != null) category.setName(request.getName());
        if (request.getSlug() != null) category.setSlug(request.getSlug());
        if (request.getImageUrl() != null) category.setImageUrl(request.getImageUrl());
        if (request.getSortOrder() != null) category.setSortOrder(request.getSortOrder());
        category = categoryRepository.save(category);
        return mapToResponse(category);
    }

    @Transactional
    public void deleteCategory(UUID id) {
        productRepository.findByCategoryId(id).forEach(product -> product.setCategory(null));
        categoryRepository.deleteById(id);
    }

    private CategoryResponse mapToResponse(Category c) {
        return CategoryResponse.builder()
                .id(c.getId()).boutiqueId(c.getBoutique().getId())
                .name(c.getName()).slug(c.getSlug())
                .imageUrl(c.getImageUrl()).sortOrder(c.getSortOrder())
                .build();
    }
}
