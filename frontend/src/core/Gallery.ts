import { z } from "zod";

const GallerySchema =
  z.object(
    { id:             z.number()
    , name:           z.string()
    , template:       z.string()
    , isPrescreened:  z.boolean()
    , description:    z.string()
    , creationTime:   z.coerce.date()
    , numApproved:    z.number()
    , numWaiting:     z.number()
    , lastSubTime:    z.coerce.date().nullable(),
    }
  );

const GalleryArraySchema = z.array(GallerySchema);

type Gallery = z.infer<typeof GallerySchema>

export { GalleryArraySchema, GallerySchema };
export type { Gallery };
