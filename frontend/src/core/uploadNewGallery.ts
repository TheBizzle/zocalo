import type { Gallery                  } from "@/core/Gallery.ts";
import { Failure, type Result, Success } from "@/core/Result.ts";
import { authorizedFetch               } from "@/core/TeacherAuth.ts";

async function uploadNewGallery( galleryName: string, template: string, isPrescreened: boolean
                               , desc: string, starterData: string): Promise<Result<Gallery>> {

  const starterConfig = new Blob([starterData], { type: "text/plain" });

  const name = galleryName.trim();
  const description = desc.trim();

  const postData = new FormData();
  postData.append("gallery-name"    , name);
  postData.append("template"        , template);
  postData.append("gets-prescreened", isPrescreened.toString());
  postData.append("description"     , description);
  postData.append("config"          , starterConfig, "config");
  const options = { method: "POST", body: postData };

  const url    = "/api/galleries/teacher/new-session";
  const result = await authorizedFetch(url, options);

  if (result.ok) {

    const id = await result.text();

    const newGallery: Gallery =
      { id
      , name
      , template
      , isPrescreened
      , description
      , numApproved:  0
      , numWaiting:   0
      , creationTime: new Date()
      , lastSubTime:  null
      };

    return new Success(newGallery);

  } else {
    return new Failure(new Error(await result.text()));
  }

}

export { uploadNewGallery };
