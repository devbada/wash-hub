package com.washhub.api.domain.file.service;

import com.washhub.api.global.error.exception.ErrorCode;
import com.washhub.api.global.error.exception.NotAcceptableException;
import com.washhub.api.infra.s3.S3Service;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import net.coobird.thumbnailator.Thumbnails;
import org.springframework.stereotype.Service;

import javax.imageio.ImageIO;
import java.awt.*;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.net.URL;

@Slf4j
@RequiredArgsConstructor
@Service
public class ImageCompositeService {

    private static final int THUMBNAIL_WIDTH = 800;
    private static final int THUMBNAIL_HEIGHT = 600;

    private final S3Service s3Service;

    /**
     * Before/After 이미지를 좌우 분할 합성하여 썸네일 생성
     *
     * @param beforeImageUrl Before 이미지 S3 URL
     * @param afterImageUrl  After 이미지 S3 URL
     * @param directory      저장 디렉토리 (예: "feeds/1")
     * @return 합성 썸네일 S3 URL
     */
    public String createComposite(String beforeImageUrl, String afterImageUrl, String directory) {
        try {
            // 1. S3에서 이미지 로드 및 리사이즈
            BufferedImage beforeImage = loadAndResize(beforeImageUrl);
            BufferedImage afterImage = loadAndResize(afterImageUrl);

            // 2. 좌우 합성 (Before | After)
            BufferedImage composite = compositeLeftRight(beforeImage, afterImage);

            // 3. JPEG 바이트 변환
            byte[] compositeBytes = toJpegBytes(composite);

            // 4. S3 업로드
            String thumbnailUrl = s3Service.uploadBytes(
                    compositeBytes, directory, "thumbnail.jpg", "image/jpeg"
            );

            log.info("Before/After 합성 썸네일 생성 완료: url={}", thumbnailUrl);
            return thumbnailUrl;

        } catch (NotAcceptableException e) {
            throw e;
        } catch (Exception e) {
            log.error("이미지 합성 실패: {}", e.getMessage());
            throw new NotAcceptableException(ErrorCode.FILE_UPLOAD_FAILED,
                    "썸네일 생성에 실패했습니다."); // TODO-minam
        }
    }

    /**
     * URL에서 이미지를 로드하고 절반 크기로 리사이즈
     */
    private BufferedImage loadAndResize(String imageUrl) throws IOException {
        BufferedImage original = ImageIO.read(new URL(imageUrl));
        if (original == null) {
            throw new NotAcceptableException(ErrorCode.INVALID_FILE_TYPE,
                    "이미지를 로드할 수 없습니다: " + imageUrl); // TODO-minam
        }

        // 합성 시 각각 절반 너비를 사용하므로 THUMBNAIL_WIDTH/2 x THUMBNAIL_HEIGHT로 리사이즈
        return Thumbnails.of(original)
                .size(THUMBNAIL_WIDTH / 2, THUMBNAIL_HEIGHT)
                .asBufferedImage();
    }

    /**
     * 두 이미지를 좌우 분할 합성
     */
    private BufferedImage compositeLeftRight(BufferedImage left, BufferedImage right) {
        BufferedImage composite = new BufferedImage(
                THUMBNAIL_WIDTH, THUMBNAIL_HEIGHT, BufferedImage.TYPE_INT_RGB
        );

        Graphics2D g2d = composite.createGraphics();
        g2d.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BILINEAR);
        g2d.setRenderingHint(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY);

        // 좌측: Before
        g2d.drawImage(left, 0, 0, THUMBNAIL_WIDTH / 2, THUMBNAIL_HEIGHT, null);

        // 우측: After
        g2d.drawImage(right, THUMBNAIL_WIDTH / 2, 0, THUMBNAIL_WIDTH / 2, THUMBNAIL_HEIGHT, null);

        // 중앙 구분선
        g2d.setColor(Color.WHITE);
        g2d.setStroke(new BasicStroke(2));
        g2d.drawLine(THUMBNAIL_WIDTH / 2, 0, THUMBNAIL_WIDTH / 2, THUMBNAIL_HEIGHT);

        g2d.dispose();
        return composite;
    }

    /**
     * BufferedImage → JPEG 바이트 배열 변환
     */
    private byte[] toJpegBytes(BufferedImage image) throws IOException {
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        Thumbnails.of(image)
                .size(THUMBNAIL_WIDTH, THUMBNAIL_HEIGHT)
                .outputFormat("jpg")
                .outputQuality(0.85)
                .toOutputStream(baos);
        return baos.toByteArray();
    }
}
