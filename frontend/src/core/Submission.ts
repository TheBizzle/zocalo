type Comment = { id: string, author: string, text: string, createdAt: Date };

type Submission =
  { id:           string
  , title:        string
  , description:  string
  , thumbnail:    string | null
  , submittedAt:  Date
  , commentCount: number
  , comments:     Array<Comment>
  };

export type { Comment, Submission };
