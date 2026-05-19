<!-- First version made by Claude Opus 4.6 -->
<template>
  <div class="comment-section">
    <h3 class="comment-heading">
      Comments
      <span class="comment-count">{{ localComments.length }}</span>
    </h3>

    <!-- Existing comments -->
    <div class="comment-thread" v-if="localComments.length > 0">
      <div v-for="c in localComments" class="comment-bubble animate-fade">
        <div class="comment-author">{{ c.author }}</div>
        <div class="comment-text">{{ c.comment }}</div>
        <div class="comment-time">{{ formatTime(c.creationTime) }}</div>
      </div>
    </div>
    <div v-else class="no-comments">
      No comments yet. Be the first!
    </div>

    <!-- Add comment form -->
    <div class="add-comment-form">
      <div class="form-group" style="margin-top: var(--space-3)">
        <label class="form-label">Commenting as <strong>{{ selfName }}</strong></label>
        <textarea v-model="newText" class="form-textarea" placeholder="Write your comment…"
                  rows="3" maxlength="1000"></textarea>
      </div>
      <div class="add-comment-actions">
        <span class="form-hint">{{ newText.length }}/1000</span>
        <button class="btn btn-primary btn-sm" @click="postComment"
                :disabled="posting || !newText.trim()">
          <span v-if="posting">Posting…</span>
          <span v-else>Post comment</span>
        </button>
      </div>
      <div class="alert alert-danger" style="margin-top: var(--space-3)" v-if="errorMsg">
        {{ errorMsg }}
      </div>
    </div>
  </div>
</template>

<script lang="ts">

  import { defineComponent, type PropType, ref } from "vue";

  import { authorizedFetch, getStudentName } from "@/core/StudentAuth.ts";
  import type { Comment                    } from "@/core/Submission.ts";

  export default defineComponent({
    name: "CommentThread"
  , props: {
      comments:       { type: Array as PropType<Array<Comment>>, default: () => [] }
    , galleryID:      { type: String, required: true }
    , submissionName: { type: String, required: true }
    }
  , setup(props) {

      const localComments = ref<Array<Comment>>([...props.comments]);
      const errorMsg      = ref("");
      const newText       = ref("");
      const posting       = ref(false);
      const selfName      = ref(getStudentName());

      function formatTime(d: Date): string {
        const dateFormat = { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" } as const;
        return d.toLocaleString("en-US", dateFormat);
      }

      async function postComment(): Promise<void> {

        errorMsg.value = "";

        const comment = newText.value.trim();

        if (newText.value.trim() === "")
          return;

        posting.value = true;

        try {

          const postData = new FormData();
          postData.append("comment", comment);
          const options = { method: "POST", body: postData };

          const url = `/api/galleries/${props.galleryID}/${props.submissionName}/student/comment`;
          const res = await authorizedFetch(url, options);

          if (res.ok) {
            localComments.value.push(
              { comment
              , author:       selfName.value
              , parentID:     null
              , creationTime: new Date()
              }
            );
          } else {
            errorMsg.value = await res.text();
          }

          newText.value = "";

        } catch (err: unknown) {
          if (err instanceof Error) {
            errorMsg.value = err.message;
          } else {
            errorMsg.value = "Could not post comment. Please try again.";
          }
        } finally {
          posting.value = false;
        }
      }

      return {
        errorMsg, formatTime, localComments, newText, postComment, posting, selfName
      };

    }
  });

</script>

<style scoped>

  .comment-section {
    display:        flex;
    flex-direction: column;
    gap:            var(--space-4);
  }

  .comment-heading {
    display:     flex;
    align-items: center;
    gap:         var(--space-3);
    font-size:   1rem;
    color:       var(--clr-ink-2);
  }

  .comment-count {
    background:    var(--clr-surface-2);
    border:        1px solid var(--clr-border);
    border-radius: 999px;
    font-size:     0.75rem;
    font-weight:   600;
    padding:       1px 8px;
    color:         var(--clr-ink-3);
    font-family:   var(--font-body);
  }

  .no-comments {
    font-size:  0.875rem;
    color:      var(--clr-muted);
    font-style: italic;
    padding:    var(--space-3) 0;
  }

  .add-comment-form {
    background:    var(--clr-surface-2);
    border:        1px solid var(--clr-border);
    border-radius: var(--radius-lg);
    padding:       var(--space-4);
  }

  .add-comment-actions {
    display:         flex;
    justify-content: space-between;
    align-items:     center;
    margin-top:      var(--space-3);
  }

  .form-row {
    display:               grid;
    grid-template-columns: 1fr;
  }

</style>
