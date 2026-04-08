package com.washhub.api.global.security;

import com.washhub.api.global.error.exception.ErrorCode;
import com.washhub.api.global.error.exception.NotAcceptableException;
import lombok.AccessLevel;
import lombok.NoArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;

import java.util.Optional;

@NoArgsConstructor(access = AccessLevel.PRIVATE)
public class SecurityUtil {

    /**
     * 현재 인증된 회원의 ID를 반환합니다.
     *
     * @return 회원 ID
     * @throws NotAcceptableException 인증 정보가 없는 경우
     */
    public static Long getCurrentMemberId() {
        return Optional.ofNullable(SecurityContextHolder.getContext().getAuthentication())
                .map(Authentication::getPrincipal)
                .filter(principal -> principal instanceof Long)
                .map(principal -> (Long) principal)
                .orElseThrow(() -> new NotAcceptableException(ErrorCode.UNAUTHORIZED, "로그인이 필요합니다.")); // TODO-minam
    }
}
