<template>
  <div class="comment-section">
    <h3 class="comment-heading">
      Comments
      <span class="comment-count">{{ localComments.length }}</span>
    </h3>

    <!-- Existing comments -->
    <div class="comment-thread" v-if="localComments.length > 0">
      <div v-for="c in localComments" :key="c.id" class="comment-bubble animate-fade">
        <div class="comment-author">{{ c.author }}</div>
        <div class="comment-text">{{ c.text }}</div>
        <div class="comment-time">{{ formatTime(c.createdAt) }}</div>
      </div>
    </div>
    <div v-else class="no-comments">
      No comments yet. Be the first!
    </div>

    <!-- Add comment form -->
    <div class="add-comment-form">
      <div class="form-row">
        <div class="form-group">
          <label class="form-label">Your name <span class="required">*</span></label>
          <input v-model="newName" class="form-input" type="text" placeholder="e.g. Jamie"
                 maxlength="60" />
        </div>
      </div>
      <div class="form-group" style="margin-top: var(--space-3)">
        <label class="form-label">Comment <span class="required">*</span></label>
        <textarea v-model="newText" class="form-textarea" placeholder="Write your comment…"
                  rows="3" maxlength="1000"></textarea>
      </div>
      <div class="add-comment-actions">
        <span class="form-hint">{{ newText.length }}/1000</span>
        <button class="btn btn-primary btn-sm" @click="postComment"
                :disabled="posting || !newName.trim() || !newText.trim()">
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

  import { defineComponent, ref } from "vue";

  import type { PropType } from "vue";

  type Comment = {
    id:        string
    author:    string
    text:      string
    createdAt: Date
  }

  export default defineComponent({
    name: "CommentThread"
  , props: {
      submissionId: { type: String, required: true }
    , comments:     { type: Array as PropType<Array<Comment>>, default: () => [] }
    }
  , setup(props) {

      const localComments = ref<Array<Comment>>([...props.comments]);
      const newName       = ref("");
      const newText       = ref("");
      const posting       = ref(false);
      const errorMsg      = ref("");

      function formatTime(d: Date): string {
        const dateFormat = { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" } as const;
        return d.toLocaleString("en-GB", dateFormat);
      }

      async function postComment(): Promise<void> {

        errorMsg.value = "";

        if (newName.value.trim() === "" || newText.value.trim() === "")
          return;

        posting.value = true;

        try {
          // TODO: API call
          // await fetch(`/api/submissions/${props.submissionId}/comments`, {
          //   method: 'POST',
          //   headers: { 'Content-Type': 'application/json' },
          //   body: JSON.stringify({ author: newName.value.trim(), text: newText.value.trim() })
          // })
          await new Promise(r => setTimeout(r, 400));

          localComments.value.push({
            id:        Date.now().toString()
          , author:    newName.value.trim()
          , text:      newText.value.trim()
          , createdAt: new Date(),
          });

          newName.value = "";
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
        errorMsg, formatTime, localComments, newName, newText, postComment, posting
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
