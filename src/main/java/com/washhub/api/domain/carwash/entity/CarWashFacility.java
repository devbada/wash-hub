package com.washhub.api.domain.carwash.entity;

import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import javax.persistence.*;

@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Table(name = "tb_car_wash_facility")
@Entity
public class CarWashFacility {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "facility_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "car_wash_id", nullable = false)
    private CarWash carWash;

    @Enumerated(EnumType.STRING)
    @Column(name = "facility_type", nullable = false, length = 30)
    private FacilityType facilityType;

    @Builder
    private CarWashFacility(CarWash carWash, FacilityType facilityType) {
        this.carWash = carWash;
        this.facilityType = facilityType;
    }
}
