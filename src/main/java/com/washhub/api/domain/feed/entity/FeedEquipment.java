package com.washhub.api.domain.feed.entity;

import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import javax.persistence.*;
import java.time.LocalDateTime;

@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Table(name = "tb_feed_equipment")
@Entity
public class FeedEquipment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "feed_equipment_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "feed_id", nullable = false)
    private Feed feed;

    @Column(name = "equipment_id", nullable = false)
    private Long equipmentId; // P1-007에서 tb_equipment 생성 후 연관관계로 변경 가능

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Builder
    private FeedEquipment(Feed feed, Long equipmentId) {
        this.feed = feed;
        this.equipmentId = equipmentId;
        this.createdAt = LocalDateTime.now();
    }
}
