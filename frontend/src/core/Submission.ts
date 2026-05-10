import { z } from "zod";

const CommentSchema =
  z.object(
    { id:           z.number()
    , comment:      z.string()
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
    , data:         z.string().nullable()
    , uploadName:   z.string()
    , image:        z.base64url()
    , isOwner:      z.boolean()
    , canModerate:  z.boolean()
    , metadata:     z.string().nullable()
    , comments:     CommentArraySchema
    , creationTime: z.coerce.date()
    }
  );

type Submission = z.infer<typeof SubmissionSchema>;
const SubmissionArraySchema = z.array(SubmissionSchema);

export { CommentArraySchema, CommentSchema, SubmissionArraySchema, SubmissionSchema };
export type { Comment, Submission };
