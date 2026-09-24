
import { S3Client, GetObjectCommand } from '@aws-sdk/client-s3';
import{ DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, GetCommand, PutCommand } from "@aws-sdk/lib-dynamodb";
import ExifReader from 'exifreader';

export const handler = async event => {

    const Bucket = `${domain_name}-images`;
    const Prefix = 'images/';

    const meta = await getEmbeddedImageMetaData(event.key, Bucket, Prefix);

    console.log(`should write: ${meta?.title || meta?.description || meta?.wiki}`)
    if (meta?.title || meta?.description || meta?.wiki) {
                     await writeMetaData(event.key, meta);
    }

    return { statusCode: 200, body: meta };

    // if (!Contents || Contents.length === 0) {
    //     return {
    //         statusCode: 404,
    //         body: { error: 'No files found in scaled subdirectory' },
    //     };
    // }
    //
    // // Filter for image files (e.g., jpg, png) and select 5 random files
    // const imageFiles = Contents.filter(obj =>
    //     obj.Key.match(/\.(jpg|jpeg|png|gif)$/i)
    // );
    //
    // imageFiles.forEach(imageFile => {
    //     getEmbeddedImageMetaData(imageFile.Key).then(meta => {
    //         if (meta.title || meta.description || meta.wiki) {
    //             writeMetaData(imageFile.Key, meta);
    //         } else {
    //             console.log("No metadata for: ", imageFile.Key);
    //         }
    //     });
    //})

    // const metadata = await getEmbeddedImageMetaData(imageKey);
    //
    // if (metadata.title || metadata.description || metadata.wiki) {
    //     await writeMetaData(imageKey, metadata);
    // }
};

async function getEmbeddedImageMetaData(key, bucket, prefix) {

    try {
        const s3Client = new S3Client({ region: 'us-east-1' });

        const getObjectCommand = new GetObjectCommand({
            Bucket: bucket,
            Prefix: prefix,
            Key: key,
        });
        const { Body } = await s3Client.send(getObjectCommand);
        const arrayBuffer = await Body.transformToByteArray();
        const buffer = Buffer.from(arrayBuffer);

        const tags = await ExifReader.load(buffer);



        const metadata = {
            title: tags["title"]?.description,
            description: tags["description"]?.description,
            wiki: tags['CreatorContactInfo']?.description?.replace('CreatorWorkUrl: ', ''),
        };

        console.log(metadata);

        return metadata;
    } catch (err) {
        console.error(err);
    }
};

async function writeMetaData(key, metadata) {

    console.log(metadata);

    const TableName = `${domain_name}-image-metadata`;

    const client = new DynamoDBClient({});
    const docClient = DynamoDBDocumentClient.from(client);

    try {
        //check for current key in dynamodb
        const {Item} = await docClient.send(
            new GetCommand({
                TableName,
                Key: { imageKey: key}
            })
        )
        if (!Item) {
            console.log("Could not find metadata for key: ", key);
            await docClient.send(new PutCommand({
                TableName,
                Item: {
                    imageKey: key,
                    ...metadata
                }
            }))

        } else {
            console.log("Found: ", key);
            //if found, read, compare, write if different
        }

    } catch (err) {
        console.error(err);
    }

};