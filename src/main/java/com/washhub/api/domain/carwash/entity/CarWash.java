package com.washhub.api.domain.carwash.entity;

import com.washhub.api.domain.member.entity.Member;
import com.washhub.api.global.common.entity.BaseEntity;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import javax.persistence.*;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Table(name = "tb_car_wash")
@Entity
public class CarWash extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "car_wash_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id", nullable = false)
    private Member member;

    @Column(name = "name", nullable = false, length = 100)
    private String name;

    @Enumerated(EnumType.STRING)
    @Column(name = "category", nullable = false, length = 30)
    private CarWashCategory category;

    @Column(name = "address", length = 300)
    private String address;

    @Column(name = "latitude", precision = 10, scale = 7)
    private BigDecimal latitude;

    @Column(name = "longitude", precision = 10, scale = 7)
    private BigDecimal longitude;

    @Column(name = "phone", length = 20)
    private String phone;

    @Column(name = "operating_hours", length = 100)
    private String operatingHours;

    @Column(name = "price_range", length = 50)
    private String priceRange;

    @Column(name = "image_url", length = 500)
    private String imageUrl;

    @Column(name = "avg_rating", nullable = false, precision = 2, scale = 1)
    private BigDecimal avgRating;

    @Column(name = "review_count", nullable = false)
    private int reviewCount;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private CarWashStatus status;

    @OneToMany(mappedBy = "carWash", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<CarWashFacility> facilities = new ArrayList<>();

    @Builder
    private CarWash(Member member, String name, CarWashCategory category,
                    String address, BigDecimal latitude, BigDecimal longitude,
                    String phone, String operatingHours, String priceRange, String imageUrl) {
        this.member = member;
        this.name = name;
        this.category = category;
        this.address = address;
        this.latitude = latitude;
        this.longitude = longitude;
        this.phone = phone;
        this.operatingHours = operatingHours;
        this.priceRange = priceRange;
        this.imageUrl = imageUrl;
        this.avgRating = BigDecimal.ZERO;
        this.reviewCount = 0;
        this.status = CarWashStatus.ACTIVE;
    }

    public void update(String name, CarWashCategory category, String address,
                       BigDecimal latitude, BigDecimal longitude,
                       String phone, String operatingHours, String priceRange, String imageUrl) {
        this.name = name;
        this.category = category;
        this.address = address;
        this.latitude = latitude;
        this.longitude = longitude;
        this.phone = phone;
        this.operatingHours = operatingHours;
        this.priceRange = priceRange;
        if (imageUrl != null) {
            this.imageUrl = imageUrl;
        }
    }

    public void softDelete() {
        this.status = CarWashStatus.DELETED;
    }

    public boolean isActive() {
        return this.status == CarWashStatus.ACTIVE;
    }

    public boolean isOwnedBy(Long memberId) {
        return this.member.getId().equals(memberId);
    }

    public void addFacility(CarWashFacility facility) {
        this.facilities.add(facility);
    }

    public void clearFacilities() {
        this.facilities.clear();
    }

    /**
     * 리뷰 추가 시 평균 별점 및 리뷰 수 갱신 (P2-002에서 사용 예정)
     */
    public void updateRatingStats(BigDecimal newAvgRating, int newReviewCount) {
        this.avgRating = newAvgRating;
        this.reviewCount = newReviewCount;
    }
}
