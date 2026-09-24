import { S3Client, GetObjectCommand, PutObjectCommand } from "@aws-sdk/client-s3";
import sharp from "sharp";

const s3 = new S3Client({});
const MAX_SIZE = 15 * 1024 * 1024; // 15 MB

export const handler = async (event) => {
    const { bucket, key } = event;

    if (!bucket || !key) {
        throw new Error("Event must contain 'bucket' and 'key'");
    }

    console.log(`Processing s3://${bucket}/${key}`);

    // Create new key: replace "images/" with "scaled/"
    const newKey = key.replace(/^images\//, "scaled/");

    // 1. Download original
    const { Body } = await s3.send(
        new GetObjectCommand({ Bucket: bucket, Key: key })
    );
    const originalBuffer = Buffer.from(await Body.transformToByteArray());
    console.log(`Original size: ${(originalBuffer.length / 1024 / 1024).toFixed(2)} MB`);

    // 2. Scale until under 15 MB
    let buffer = originalBuffer;
    let quality = 85;
    let width = null;

    buffer = await sharp(originalBuffer)
        .jpeg({ quality, mozjpeg: true })
        .toBuffer();

    while (buffer.length > MAX_SIZE && quality >= 50) {
        const meta = await sharp(originalBuffer).metadata();
        width = Math.round((width || meta.width || 4000) * 0.85);

        buffer = await sharp(originalBuffer)
            .resize({ width, withoutEnlargement: true })
            .jpeg({ quality, mozjpeg: true })
            .toBuffer();

        console.log(`→ width=${width}, quality=${quality} → ${(buffer.length / 1024 / 1024).toFixed(2)} MB`);
        quality -= 5;
    }

    // Final safety resize
    if (buffer.length > MAX_SIZE) {
        buffer = await sharp(originalBuffer)
            .resize({ width: 1800, withoutEnlargement: true })
            .jpeg({ quality: 90, mozjpeg: true })
            .toBuffer();
    }

    console.log(`Final size: ${(buffer.length / 1024 / 1024).toFixed(2)} MB`);
    console.log(`Uploading to: s3://${bucket}/${newKey}`);

    // 3. Upload to the new key under /scaled
    await s3.send(
        new PutObjectCommand({
            Bucket: bucket,
            Key: newKey,
            Body: buffer,
            ContentType: "image/jpeg",
            CacheControl: "public, max-age=31536000",
        })
    );

    return {
        statusCode: 200,
        originalKey: key,
        scaledKey: newKey,
        originalSize: originalBuffer.length,
        finalSize: buffer.length,
        message: "Image successfully scaled and saved under /scaled",
    };
};