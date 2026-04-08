package com.washhub.api.global.error.exception;

import lombok.AllArgsConstructor;
import lombok.Getter;

@Getter
@AllArgsConstructor
public enum ErrorCode {

    // 공통
    INVALID_INPUT(400, "잘못된 입력값입니다."),
    UNAUTHORIZED(401, "인증이 필요합니다."),
    FORBIDDEN(403, "접근 권한이 없습니다."),
    NOT_FOUND(404, "요청한 리소스를 찾을 수 없습니다."),
    NOT_ACCEPTABLE(406, "요청을 처리할 수 없습니다."),
    INTERNAL_SERVER_ERROR(500, "서버 내부 오류가 발생했습니다."),

    // 인증
    EXPIRED_TOKEN(401, "토큰이 만료되었습니다."),
    INVALID_TOKEN(401, "유효하지 않은 토큰입니다."),

    // 파일
    FILE_UPLOAD_FAILED(500, "파일 업로드에 실패했습니다."),
    INVALID_FILE_TYPE(400, "허용되지 않는 파일 형식입니다."),
    FILE_SIZE_EXCEEDED(400, "파일 크기가 제한을 초과했습니다.");

    private final int status;
    private final String message;
}
