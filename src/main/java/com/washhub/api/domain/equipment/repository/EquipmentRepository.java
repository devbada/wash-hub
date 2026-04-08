package com.washhub.api.domain.equipment.repository;

import com.washhub.api.domain.equipment.entity.Equipment;
import com.washhub.api.domain.equipment.entity.EquipmentCategory;
import com.washhub.api.domain.equipment.entity.EquipmentStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface EquipmentRepository extends JpaRepository<Equipment, Long> {

    @Query("SELECT e FROM Equipment e JOIN FETCH e.member " +
            "WHERE e.status = :status " +
            "AND (:category IS NULL OR e.category = :category) " +
            "ORDER BY e.createdAt DESC")
    Page<Equipment> findAllByStatusAndCategory(
            @Param("status") EquipmentStatus status,
            @Param("category") EquipmentCategory category,
            Pageable pageable);

    @Query("SELECT e FROM Equipment e JOIN FETCH e.member " +
            "WHERE e.id = :equipmentId AND e.status = :status")
    Optional<Equipment> findByIdAndStatus(
            @Param("equipmentId") Long equipmentId,
            @Param("status") EquipmentStatus status);

    @Query("SELECT e FROM Equipment e JOIN FETCH e.member " +
            "WHERE e.status = :status " +
            "AND LOWER(e.name) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
            "ORDER BY e.createdAt DESC")
    Page<Equipment> searchByName(
            @Param("status") EquipmentStatus status,
            @Param("keyword") String keyword,
            Pageable pageable);
}
