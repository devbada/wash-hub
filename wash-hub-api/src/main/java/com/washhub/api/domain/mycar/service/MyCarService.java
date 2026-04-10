package com.washhub.api.domain.mycar.service;

import com.washhub.api.domain.member.entity.Member;
import com.washhub.api.domain.member.repository.MemberRepository;
import com.washhub.api.domain.mycar.dto.MyCarCreateRequest;
import com.washhub.api.domain.mycar.dto.MyCarResponse;
import com.washhub.api.domain.mycar.dto.MyCarUpdateRequest;
import com.washhub.api.domain.mycar.entity.MyCar;
import com.washhub.api.domain.mycar.repository.MyCarRepository;
import com.washhub.api.global.error.exception.ErrorCode;
import com.washhub.api.global.error.exception.NotAcceptableException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@RequiredArgsConstructor
@Service
public class MyCarService {

    private final MyCarRepository myCarRepository;
    private final MemberRepository memberRepository;

    /**
     * 내 차량 목록 조회
     */
    @Transactional(readOnly = true)
    public List<MyCarResponse> getMyCars(Long memberId) {
        List<MyCar> persistMyCars = myCarRepository.findByMemberIdOrderByIsPrimaryDescCreatedAtDesc(memberId);
        return persistMyCars.stream()
                .map(MyCarResponse::from)
                .collect(Collectors.toList());
    }

    /**
     * 차량 등록
     */
    @Transactional
    public MyCarResponse createMyCar(Long memberId, MyCarCreateRequest request) {
        Member persistMember = memberRepository.findById(memberId)
                .orElseThrow(() -> new NotAcceptableException(ErrorCode.NOT_FOUND, "회원을 찾을 수 없습니다.")); // TODO-minam

        MyCar persistMyCar = MyCar.builder()
                .member(persistMember)
                .carModel(request.getCarModel())
                .carColor(request.getCarColor())
                .carYear(request.getCarYear())
                .imageUrl(request.getImageUrl())
                .build();

        // 첫 번째 차량은 자동으로 대표 차량 설정
        if (myCarRepository.countByMemberId(memberId) == 0) {
            persistMyCar.setPrimary(true);
        }

        persistMyCar = myCarRepository.save(persistMyCar);
        log.info("차량 등록 완료: myCarId={}, memberId={}", persistMyCar.getId(), memberId);
        return MyCarResponse.from(persistMyCar);
    }

    /**
     * 차량 수정 (본인만)
     */
    @Transactional
    public MyCarResponse updateMyCar(Long myCarId, Long memberId, MyCarUpdateRequest request) {
        MyCar persistMyCar = myCarRepository.findById(myCarId)
                .orElseThrow(() -> new NotAcceptableException(ErrorCode.NOT_FOUND, "차량을 찾을 수 없습니다.")); // TODO-minam

        if (!persistMyCar.isOwnedBy(memberId)) {
            throw new NotAcceptableException(ErrorCode.FORBIDDEN, "본인의 차량만 수정할 수 있습니다."); // TODO-minam
        }

        persistMyCar.update(request.getCarModel(), request.getCarColor(), request.getCarYear(), request.getImageUrl());
        log.info("차량 수정 완료: myCarId={}", myCarId);
        return MyCarResponse.from(persistMyCar);
    }

    /**
     * 차량 삭제 (본인만)
     */
    @Transactional
    public void deleteMyCar(Long myCarId, Long memberId) {
        MyCar persistMyCar = myCarRepository.findById(myCarId)
                .orElseThrow(() -> new NotAcceptableException(ErrorCode.NOT_FOUND, "차량을 찾을 수 없습니다.")); // TODO-minam

        if (!persistMyCar.isOwnedBy(memberId)) {
            throw new NotAcceptableException(ErrorCode.FORBIDDEN, "본인의 차량만 삭제할 수 있습니다."); // TODO-minam
        }

        myCarRepository.delete(persistMyCar);
        log.info("차량 삭제 완료: myCarId={}", myCarId);
    }
}
