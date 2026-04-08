package com.washhub.api.domain.mycar.repository;

import com.washhub.api.domain.mycar.entity.MyCar;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface MyCarRepository extends JpaRepository<MyCar, Long> {

    List<MyCar> findByMemberIdOrderByIsPrimaryDescCreatedAtDesc(Long memberId);

    long countByMemberId(Long memberId);
}
