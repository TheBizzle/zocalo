type Gallery = {
  id:             number
  name:           string
  template:       string
  isModerated:    boolean
  uploadCount:    number
  pendingCount:   number
  createdAt:      Date
  lastSubmission: Date | null
  description:    string
}

export type { Gallery };
