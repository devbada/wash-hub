package com.washhub.api.domain.mycar.entity;

import com.washhub.api.domain.member.entity.Member;
import com.washhub.api.global.common.entity.BaseEntity;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import javax.persistence.*;

@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Table(name = "tb_my_car")
@Entity
public class MyCar extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "my_car_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id", nullable = false)
    private Member member;

    @Column(name = "car_model", nullable = false, length = 100)
    private String carModel;

    @Column(name = "car_color", length = 50)
    private String carColor;

    @Column(name = "car_year")
    private Integer carYear;

    @Column(name = "image_url", length = 500)
    private String imageUrl;

    @Column(name = "is_primary", nullable = false)
    private boolean isPrimary;

    @Builder
    private MyCar(Member member, String carModel, String carColor, Integer carYear, String imageUrl) {
        this.member = member;
        this.carModel = carModel;
        this.carColor = carColor;
        this.carYear = carYear;
        this.imageUrl = imageUrl;
        this.isPrimary = false;
    }

    public void update(String carModel, String carColor, Integer carYear, String imageUrl) {
        this.carModel = carModel;
        this.carColor = carColor;
        this.carYear = carYear;
        this.imageUrl = imageUrl;
    }

    public void setPrimary(boolean isPrimary) {
        this.isPrimary = isPrimary;
    }

    public boolean isOwnedBy(Long memberId) {
        return this.member.getId().equals(memberId);
    }
}
