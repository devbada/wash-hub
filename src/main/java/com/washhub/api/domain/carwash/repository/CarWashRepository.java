package com.washhub.api.domain.carwash.repository;

import com.washhub.api.domain.carwash.entity.CarWash;
import com.washhub.api.domain.carwash.entity.CarWashCategory;
import com.washhub.api.domain.carwash.entity.CarWashStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface CarWashRepository extends JpaRepository<CarWash, Long> {

    @Query("SELECT cw FROM CarWash cw JOIN FETCH cw.member " +
            "WHERE cw.status = :status " +
            "AND (:category IS NULL OR cw.category = :category) " +
            "ORDER BY cw.createdAt DESC")
    Page<CarWash> findAllByStatusAndCategory(
            @Param("status") CarWashStatus status,
            @Param("category") CarWashCategory category,
            Pageable pageable);

    @Query("SELECT cw FROM CarWash cw JOIN FETCH cw.member " +
            "LEFT JOIN FETCH cw.facilities " +
            "WHERE cw.id = :carWashId AND cw.status = :status")
    Optional<CarWash> findByIdAndStatusWithFacilities(
            @Param("carWashId") Long carWashId,
            @Param("status") CarWashStatus status);

    @Query("SELECT cw FROM CarWash cw JOIN FETCH cw.member " +
            "WHERE cw.status = :status " +
            "AND LOWER(cw.name) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
            "ORDER BY cw.createdAt DESC")
    Page<CarWash> searchByName(
            @Param("status") CarWashStatus status,
            @Param("keyword") String keyword,
            Pageable pageable);
}
