package com.washhub.api.domain.file.service;

import com.washhub.api.global.error.exception.ErrorCode;
import com.washhub.api.global.error.exception.NotAcceptableException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.InputStream;
import java.util.Arrays;
import java.util.List;

@Slf4j
@Component
public class FileValidator {

    private static final long MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB

    private static final List<String> ALLOWED_EXTENSIONS = Arrays.asList(
            "jpg", "jpeg", "png", "heic", "webp"
    );

    // Magic Number 정의 (파일 시그니처)
    private static final byte[] JPEG_MAGIC = new byte[]{(byte) 0xFF, (byte) 0xD8, (byte) 0xFF};
    private static final byte[] PNG_MAGIC = new byte[]{(byte) 0x89, 0x50, 0x4E, 0x47};
    private static final byte[] WEBP_RIFF = new byte[]{0x52, 0x49, 0x46, 0x46}; // "RIFF"

    /**
     * 이미지 파일 종합 검증
     * - 확장자, 크기, Magic Number 검사
     */
    public void validateImage(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new NotAcceptableException("업로드할 파일이 없습니다."); // TODO-minam
        }

        validateFileSize(file);
        validateExtension(file);
        validateMagicNumber(file);
    }

    /**
     * 파일 크기 검증
     */
    private void validateFileSize(MultipartFile file) {
        if (file.getSize() > MAX_FILE_SIZE) {
            throw new NotAcceptableException(ErrorCode.FILE_SIZE_EXCEEDED,
                    "파일 크기는 10MB를 초과할 수 없습니다."); // TODO-minam
        }
    }

    /**
     * 확장자 검증
     */
    private void validateExtension(MultipartFile file) {
        String originalFilename = file.getOriginalFilename();
        if (originalFilename == null || !originalFilename.contains(".")) {
            throw new NotAcceptableException(ErrorCode.INVALID_FILE_TYPE,
                    "파일 확장자를 확인할 수 없습니다."); // TODO-minam
        }

        String extension = originalFilename.substring(originalFilename.lastIndexOf(".") + 1).toLowerCase();
        if (!ALLOWED_EXTENSIONS.contains(extension)) {
            throw new NotAcceptableException(ErrorCode.INVALID_FILE_TYPE,
                    "허용되지 않는 파일 형식입니다. 허용: " + String.join(", ", ALLOWED_EXTENSIONS)); // TODO-minam
        }
    }

    /**
     * Magic Number(파일 시그니처) 검증
     * - 확장자 위변조 방지
     */
    private void validateMagicNumber(MultipartFile file) {
        try (InputStream inputStream = file.getInputStream()) {
            byte[] header = new byte[12];
            int bytesRead = inputStream.read(header);
            if (bytesRead < 3) {
                throw new NotAcceptableException(ErrorCode.INVALID_FILE_TYPE,
                        "유효하지 않은 파일입니다."); // TODO-minam
            }

            if (startsWith(header, JPEG_MAGIC)) return;  // JPEG
            if (startsWith(header, PNG_MAGIC)) return;    // PNG
            if (startsWith(header, WEBP_RIFF)) return;    // WebP (RIFF 컨테이너)

            // HEIC: "ftyp" 시그니처 (offset 4~7)
            if (bytesRead >= 8) {
                byte[] ftypSignature = Arrays.copyOfRange(header, 4, 8);
                if (new String(ftypSignature).equals("ftyp")) return; // HEIC/HEIF
            }

            log.warn("Magic Number 불일치: file={}", file.getOriginalFilename());
            throw new NotAcceptableException(ErrorCode.INVALID_FILE_TYPE,
                    "파일 내용이 확장자와 일치하지 않습니다."); // TODO-minam

        } catch (IOException e) {
            log.error("Magic Number 검증 실패: {}", e.getMessage());
            throw new NotAcceptableException(ErrorCode.INVALID_FILE_TYPE,
                    "파일 검증 중 오류가 발생했습니다."); // TODO-minam
        }
    }

    /**
     * 바이트 배열 시작 부분 비교
     */
    private boolean startsWith(byte[] source, byte[] target) {
        if (source.length < target.length) return false;
        for (int i = 0; i < target.length; i++) {
            if (source[i] != target[i]) return false;
        }
        return true;
    }
}
