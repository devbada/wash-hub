package com.washhub.api.domain.equipment.entity;

import com.washhub.api.domain.member.entity.Member;
import com.washhub.api.global.common.entity.BaseEntity;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import javax.persistence.*;
import java.math.BigDecimal;

@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Table(name = "tb_equipment")
@Entity
public class Equipment extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "equipment_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id", nullable = false)
    private Member member;

    @Enumerated(EnumType.STRING)
    @Column(name = "category", nullable = false, length = 30)
    private EquipmentCategory category;

    @Column(name = "name", nullable = false, length = 100)
    private String name;

    @Column(name = "brand", length = 100)
    private String brand;

    @Column(name = "description", columnDefinition = "TEXT")
    private String description;

    @Column(name = "image_url", length = 500)
    private String imageUrl;

    @Column(name = "avg_rating", nullable = false, precision = 2, scale = 1)
    private BigDecimal avgRating;

    @Column(name = "review_count", nullable = false)
    private int reviewCount;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private EquipmentStatus status;

    @Builder
    private Equipment(Member member, EquipmentCategory category, String name,
                      String brand, String description, String imageUrl) {
        this.member = member;
        this.category = category;
        this.name = name;
        this.brand = brand;
        this.description = description;
        this.imageUrl = imageUrl;
        this.avgRating = BigDecimal.ZERO;
        this.reviewCount = 0;
        this.status = EquipmentStatus.ACTIVE;
    }

    public void update(String name, String brand, String description,
                       EquipmentCategory category, String imageUrl) {
        this.name = name;
        this.brand = brand;
        this.description = description;
        this.category = category;
        if (imageUrl != null) {
            this.imageUrl = imageUrl;
        }
    }

    public void softDelete() {
        this.status = EquipmentStatus.DELETED;
    }

    public boolean isActive() {
        return this.status == EquipmentStatus.ACTIVE;
    }

    public boolean isOwnedBy(Long memberId) {
        return this.member.getId().equals(memberId);
    }

    /**
     * 리뷰 추가 시 평균 별점 및 리뷰 수 갱신 (P2-001에서 사용 예정)
     */
    public void updateRatingStats(BigDecimal newAvgRating, int newReviewCount) {
        this.avgRating = newAvgRating;
        this.reviewCount = newReviewCount;
    }
}
