package com.washhub.api.domain.washlog.entity;

import com.washhub.api.domain.member.entity.Member;
import com.washhub.api.domain.mycar.entity.MyCar;
import com.washhub.api.global.common.entity.BaseEntity;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import javax.persistence.*;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Table(name = "tb_wash_log")
@Entity
public class WashLog extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "wash_log_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id", nullable = false)
    private Member member;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "my_car_id")
    private MyCar myCar;

    @Column(name = "feed_id")
    private Long feedId;

    @Column(name = "car_wash_id")
    private Long carWashId;

    @Column(name = "wash_date", nullable = false)
    private LocalDate washDate;

    @Column(name = "memo", columnDefinition = "TEXT")
    private String memo;

    @OneToMany(mappedBy = "washLog", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<WashLogEquipment> equipments = new ArrayList<>();

    @Builder
    private WashLog(Member member, MyCar myCar, Long feedId, Long carWashId, LocalDate washDate, String memo) {
        this.member = member;
        this.myCar = myCar;
        this.feedId = feedId;
        this.carWashId = carWashId;
        this.washDate = washDate;
        this.memo = memo;
    }

    public boolean isOwnedBy(Long memberId) {
        return this.member.getId().equals(memberId);
    }

    public void addEquipment(WashLogEquipment equipment) {
        this.equipments.add(equipment);
    }
}
