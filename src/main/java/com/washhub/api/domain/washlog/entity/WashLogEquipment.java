package com.washhub.api.domain.washlog.entity;

import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import javax.persistence.*;
import java.time.LocalDateTime;

@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Table(name = "tb_wash_log_equipment")
@Entity
public class WashLogEquipment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "wash_log_equipment_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "wash_log_id", nullable = false)
    private WashLog washLog;

    @Column(name = "equipment_id", nullable = false)
    private Long equipmentId;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Builder
    private WashLogEquipment(WashLog washLog, Long equipmentId) {
        this.washLog = washLog;
        this.equipmentId = equipmentId;
        this.createdAt = LocalDateTime.now();
    }
}
