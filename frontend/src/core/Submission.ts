import { z } from "zod";

const CommentSchema =
  z.object(
    { comment:      z.string()
    , author:       z.string()
    , parentID:     z.number().nullable()
    , creationTime: z.coerce.date()
    }
  );

type Comment = z.infer<typeof CommentSchema>;
const CommentArraySchema = z.array(CommentSchema);

const BroadcastCommentSchema =
  z.object(
    { comment:     CommentSchema
    , commentedID: z.number()
    }
  );

const SubmissionSchema =
  z.object(
    { id:           z.number()
    , data:         z.string().nullish()
    , uploader:     z.string()
    , image:        z.union([ z.base64().transform((s) => `data:image/png;base64,${s}`)
                            , z.string().transform((s) => `data:image/svg+xml,${encodeURIComponent(s)}`)])
    , isOwner:      z.boolean()
    , canModerate:  z.boolean()
    , metadata:     z.string().nullish()
    , comments:     CommentArraySchema.nullish().transform((cs) => cs ?? [])
    , creationTime: z.coerce.date()
    }
  );

type Submission = z.infer<typeof SubmissionSchema>;

const GalleryMetadataSchema =
  z.object(
    { galleryName: z.string()
    , isModerated: z.boolean()
    }
  );

const DeletedSubmissionSchema =
  z.object(
    { deletedID: z.number()
    }
  );

export { BroadcastCommentSchema, CommentArraySchema, CommentSchema, DeletedSubmissionSchema
       , GalleryMetadataSchema, SubmissionSchema };
export type { Comment, Submission };
