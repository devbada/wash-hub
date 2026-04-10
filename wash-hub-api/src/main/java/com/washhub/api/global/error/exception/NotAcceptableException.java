package com.washhub.api.global.error.exception;

import lombok.Getter;

@Getter
public class NotAcceptableException extends RuntimeException {

    private final ErrorCode errorCode;

    public NotAcceptableException(String message) { // TODO-minam
        super(message);
        this.errorCode = ErrorCode.NOT_ACCEPTABLE;
    }

    public NotAcceptableException(ErrorCode errorCode) { // TODO-minam
        super(errorCode.getMessage());
        this.errorCode = errorCode;
    }

    public NotAcceptableException(ErrorCode errorCode, String message) { // TODO-minam
        super(message);
        this.errorCode = errorCode;
    }
}
