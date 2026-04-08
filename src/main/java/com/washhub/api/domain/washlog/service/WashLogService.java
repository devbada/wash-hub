package com.washhub.api.domain.washlog.service;

import com.washhub.api.domain.member.entity.Member;
import com.washhub.api.domain.member.repository.MemberRepository;
import com.washhub.api.domain.mycar.entity.MyCar;
import com.washhub.api.domain.mycar.repository.MyCarRepository;
import com.washhub.api.domain.washlog.dto.WashLogCreateRequest;
import com.washhub.api.domain.washlog.dto.WashLogResponse;
import com.washhub.api.domain.washlog.dto.WashStatsResponse;
import com.washhub.api.domain.washlog.entity.WashLog;
import com.washhub.api.domain.washlog.entity.WashLogEquipment;
import com.washhub.api.domain.washlog.repository.WashLogRepository;
import com.washhub.api.global.common.dto.PageResponse;
import com.washhub.api.global.error.exception.ErrorCode;
import com.washhub.api.global.error.exception.NotAcceptableException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@Slf4j
@RequiredArgsConstructor
@Service
public class WashLogService {

    private final WashLogRepository washLogRepository;
    private final MyCarRepository myCarRepository;
    private final MemberRepository memberRepository;

    /**
     * 세차 기록 목록 (페이징)
     */
    @Transactional(readOnly = true)
    public PageResponse<WashLogResponse> getWashLogs(Long memberId, Pageable pageable) {
        Page<WashLog> persistWashLogs = washLogRepository.findByMemberIdOrderByWashDateDesc(memberId, pageable);
        Page<WashLogResponse> responsePage = persistWashLogs.map(WashLogResponse::from);
        return PageResponse.from(responsePage);
    }

    /**
     * 세차 기록 추가
     */
    @Transactional
    public WashLogResponse createWashLog(Long memberId, WashLogCreateRequest request) {
        Member persistMember = memberRepository.findById(memberId)
                .orElseThrow(() -> new NotAcceptableException(ErrorCode.NOT_FOUND, "회원을 찾을 수 없습니다.")); // TODO-minam

        MyCar persistMyCar = null;
        if (request.getMyCarId() != null) {
            persistMyCar = myCarRepository.findById(request.getMyCarId())
                    .filter(car -> car.isOwnedBy(memberId))
                    .orElseThrow(() -> new NotAcceptableException(ErrorCode.NOT_FOUND, "차량을 찾을 수 없습니다.")); // TODO-minam
        }

        WashLog persistWashLog = WashLog.builder()
                .member(persistMember)
                .myCar(persistMyCar)
                .feedId(request.getFeedId())
                .carWashId(request.getCarWashId())
                .washDate(request.getWashDate())
                .memo(request.getMemo())
                .build();
        persistWashLog = washLogRepository.save(persistWashLog);

        // 사용 케미컬 연결
        final WashLog savedWashLog = persistWashLog;
        Optional.ofNullable(request.getEquipmentIds()).ifPresent(ids ->
                ids.forEach(equipmentId -> {
                    WashLogEquipment equipment = WashLogEquipment.builder()
                            .washLog(savedWashLog)
                            .equipmentId(equipmentId)
                            .build();
                    savedWashLog.addEquipment(equipment);
                })
        );

        log.info("세차 기록 추가 완료: washLogId={}, memberId={}", savedWashLog.getId(), memberId);
        return WashLogResponse.from(savedWashLog);
    }

    /**
     * 세차 기록 상세
     */
    @Transactional(readOnly = true)
    public WashLogResponse getWashLogDetail(Long washLogId, Long memberId) {
        WashLog persistWashLog = washLogRepository.findById(washLogId)
                .orElseThrow(() -> new NotAcceptableException(ErrorCode.NOT_FOUND, "세차 기록을 찾을 수 없습니다.")); // TODO-minam

        if (!persistWashLog.isOwnedBy(memberId)) {
            throw new NotAcceptableException(ErrorCode.FORBIDDEN, "본인의 세차 기록만 조회할 수 있습니다."); // TODO-minam
        }

        return WashLogResponse.from(persistWashLog);
    }

    /**
     * 세차 기록 삭제
     */
    @Transactional
    public void deleteWashLog(Long washLogId, Long memberId) {
        WashLog persistWashLog = washLogRepository.findById(washLogId)
                .orElseThrow(() -> new NotAcceptableException(ErrorCode.NOT_FOUND, "세차 기록을 찾을 수 없습니다.")); // TODO-minam

        if (!persistWashLog.isOwnedBy(memberId)) {
            throw new NotAcceptableException(ErrorCode.FORBIDDEN, "본인의 세차 기록만 삭제할 수 있습니다."); // TODO-minam
        }

        washLogRepository.delete(persistWashLog);
        log.info("세차 기록 삭제 완료: washLogId={}", washLogId);
    }

    /**
     * 월별 세차 횟수 통계
     */
    @Transactional(readOnly = true)
    public List<WashStatsResponse> getMonthlyStats(Long memberId) {
        List<Object[]> persistStats = washLogRepository.findMonthlyStatsByMemberId(memberId);
        return persistStats.stream()
                .map(row -> new WashStatsResponse(
                        ((Number) row[0]).intValue(),
                        ((Number) row[1]).intValue(),
                        ((Number) row[2]).longValue()
                ))
                .collect(Collectors.toList());
    }
}
