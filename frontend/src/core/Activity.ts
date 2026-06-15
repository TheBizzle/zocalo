// hasExternalStarter: Creates a button that links to starter
// hasLoadableWork:    Creates a button in the detail modal for loading in primary frame
// isSplit:            Creates separate gallery and primary frames
// name:               Identifier; differentiator
// sharingStyle:
//   * file-picker: User chooses a file to upload from disk
//   * export:      Content is automatically pulled from primary frame
//   * clipboard:   User gets a button for pasting clipboard contents

type Activity =
  { readonly hasExternalStarter: boolean
  , readonly hasLoadableWork:    boolean
  , readonly isSplit:            boolean
  , readonly name:               "demo" | "fake activity" | "geogebra" | "google-docs"
  , readonly sharingStyle:       "clipboard" | "export" | "file-picker"
  }

export type { Activity };
