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

const SubmissionSchema =
  z.object(
    { id:           z.number()
    , data:         z.string().nullish()
    , uploadName:   z.string()
    , image:        z.base64().transform((s) => `data:image/png;base64,${s}`)
    , isOwner:      z.boolean()
    , canModerate:  z.boolean()
    , metadata:     z.string().nullish()
    , comments:     CommentArraySchema.nullish().transform((cs) => cs ?? [])
    , creationTime: z.coerce.date()
    }
  );

type Submission = z.infer<typeof SubmissionSchema>;

const AllSubmissionsSchema =
  z.object(
    { galleryName: z.string()
    , isModerated: z.boolean()
    , submissions: z.array(SubmissionSchema)
    }
  );

export { AllSubmissionsSchema, CommentArraySchema, CommentSchema, SubmissionSchema };
export type { Comment, Submission };
