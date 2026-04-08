package com.washhub.api.infra.kakao;

import com.washhub.api.global.error.exception.ErrorCode;
import com.washhub.api.global.error.exception.NotAcceptableException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.*;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

@Slf4j
@Component
public class KakaoApiClient {

    private static final String KAKAO_USER_INFO_URL = "https://kapi.kakao.com/v2/user/me";

    private final RestTemplate restTemplate;

    public KakaoApiClient() {
        this.restTemplate = new RestTemplate();
    }

    /**
     * 카카오 access token으로 사용자 정보를 조회합니다.
     *
     * @param accessToken 카카오에서 발급받은 access token
     * @return 카카오 사용자 정보
     */
    public KakaoUserInfo getUserInfo(String accessToken) {
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(accessToken);
        headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);

        HttpEntity<Void> request = new HttpEntity<>(headers);

        try {
            ResponseEntity<KakaoUserInfo> response = restTemplate.exchange(
                    KAKAO_USER_INFO_URL,
                    HttpMethod.GET,
                    request,
                    KakaoUserInfo.class
            );

            if (response.getBody() == null) {
                throw new NotAcceptableException(ErrorCode.UNAUTHORIZED, "카카오 사용자 정보를 가져올 수 없습니다."); // TODO-minam
            }

            log.info("카카오 사용자 정보 조회 성공: providerId={}", response.getBody().getProviderId());
            return response.getBody();

        } catch (RestClientException e) {
            log.error("카카오 API 호출 실패: {}", e.getMessage());
            throw new NotAcceptableException(ErrorCode.UNAUTHORIZED, "카카오 인증에 실패했습니다."); // TODO-minam
        }
    }
}
