import ExifReader from 'exifreader';
import { S3Client, ListObjectsV2Command, GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, GetCommand } from "@aws-sdk/lib-dynamodb";

export const handler = async event => {

    const requestedKey = event?.params?.querystring?.init;

    const s3Client = new S3Client({ region: 'us-east-1' });
    const bucket = `${image_bucket_name}`;
    const prefix = 'scaled/';
    const expiresIn = 3600; // URL expiration in seconds

    try {

        const getRequestedImage = async () => {

            if (requestedKey) {
                try {
                    const key = atob(requestedKey);
                    const requestedCommand = new ListObjectsV2Command({
                        Bucket: bucket,
                        Prefix: key
                    })



                    const { Contents } = await s3Client.send(requestedCommand);
                    return Contents;
                } catch (er) {
                    console.log(er);
                }
            }
            return undefined;
        }

        const requestedImage = await getRequestedImage();

        // List objects in the scaled subdirectory
        const listCommand = new ListObjectsV2Command({
            Bucket: bucket,
            Prefix: prefix,
        });
        const { Contents } = await s3Client.send(listCommand);

        if (!Contents || Contents.length === 0) {
            return {
                statusCode: 404,
                body: { error: 'No files found in scaled subdirectory' },
            };
        }

        // Filter for image files (e.g., jpg, png) and select 5 random files
        const imageFiles = Contents.filter(obj =>
            obj.Key.match(/\.(jpg|jpeg|png|gif)$/i)
        );

        const IMAGE_COUNT = event?.context?.stage === 'main' ? 10 : 10;

        const randomFiles = imageFiles
            .sort(() => Math.random() - 0.5) // Shuffle
            .slice(0, Math.min(IMAGE_COUNT, imageFiles.length));

        if (randomFiles.length === 0) {
            return {
                statusCode: 404,
                body: JSON.stringify({ error: 'No image files found in scaled subdirectory' }),
            };
        }

        if (requestedImage?.length > 0) {
            randomFiles.unshift(requestedImage[0])
        }

        console.log(randomFiles);

        // Generate presigned URLs and retrieve metadata for each selected file
        const urls = await Promise.all(
            randomFiles.map(async (file) => {
                // Get presigned URL
                const command = new GetObjectCommand({
                    Bucket: bucket,
                    Key: file.Key,
                });
                const url = await getSignedUrl(s3Client, command, { expiresIn });
                const customUrl = url.replace(`s3.us-east-1.amazonaws.com/${image_bucket_name}/`, `images.${domain_name}/`);

                const dynamoData = async imageKey => {

                    console.log('dynamoData key: ', imageKey);
                    const client = new DynamoDBClient({});
                    const docClient = DynamoDBDocumentClient.from(client);

                    const { Item } = await docClient.send(new GetCommand({
                        TableName: `${dynambo_db_table_name}`,
                        Key: { imageKey }
                    }));

                    console.log(Item);
                    return Item;
                }

                const dd = await dynamoData(file.Key);
                //return { key: file.Key, url: customUrl, metadata: null};
                return { key: file.Key, url: customUrl, metadata: dd };
            })
        );

        return {
            statusCode: 200,
            body: urls
        };
    } catch (error) {
        console.error('Error:', error);
        return {
            statusCode: 500,
            body: JSON.stringify({ error: error.message }),
        };
    }
};