package com.washhub.api.domain.washlog.repository;

import com.washhub.api.domain.washlog.entity.WashLog;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface WashLogRepository extends JpaRepository<WashLog, Long> {

    Page<WashLog> findByMemberIdOrderByWashDateDesc(Long memberId, Pageable pageable);

    /**
     * 월별 세차 횟수 통계
     * 결과: [year, month, count]
     */
    @Query("SELECT YEAR(w.washDate), MONTH(w.washDate), COUNT(w) " +
            "FROM WashLog w " +
            "WHERE w.member.id = :memberId " +
            "GROUP BY YEAR(w.washDate), MONTH(w.washDate) " +
            "ORDER BY YEAR(w.washDate) DESC, MONTH(w.washDate) DESC")
    List<Object[]> findMonthlyStatsByMemberId(@Param("memberId") Long memberId);
}
