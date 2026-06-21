// hasLoadableWork: Creates a button in the detail modal for loading in primary frame
// isSplit:         Creates separate gallery and primary frames
// name:            Identifier; differentiator
//
// sharingStyle:
//   * file-picker: User chooses a file to upload from disk
//   * export:      Content is automatically pulled from primary frame
//   * clipboard:   User gets a button for pasting clipboard contents
//
// starterKeys: Strings indicating how many starter panels should be shown, and what key each should get bound
//              to.
//
// starterMode:
//   * none:     Teacher gets no field for providing a starter
//   * internal: Starter is automatically loaded when the page loads
//   * external: User gets a button that links to starter

type Activity =
  { readonly hasLoadableWork: boolean
  , readonly isSplit:         boolean
  , readonly name:            "demo" | "fake activity" | "geogebra" | "google-docs" | "netlogo" | "netlogo-world" | "segregation"
  , readonly sharingStyle:    "clipboard" | "export" | "file-picker"
  , readonly starterKeys:     Array<string>
  , readonly starterMode:     "none" | "internal" | "external"
  }

const activities: Record<string, Activity>  =
  { "demo":          { hasLoadableWork: false, isSplit: false, name:          "demo", sharingStyle: "file-picker", starterKeys:                  [], starterMode:     "none" }
  , "geogebra":      { hasLoadableWork:  true, isSplit:  true, name:      "geogebra", sharingStyle:      "export", starterKeys: [           ".ggb"], starterMode: "internal" }
  , "google-docs":   { hasLoadableWork:  true, isSplit:  true, name:   "google-docs", sharingStyle:   "clipboard", starterKeys: [            "URL"], starterMode: "external" }
  , "netlogo":       { hasLoadableWork:  true, isSplit:  true, name:       "netlogo", sharingStyle:      "export", starterKeys: [        ".nlogox"], starterMode: "internal" }
  , "netlogo-world": { hasLoadableWork:  true, isSplit:  true, name: "netlogo-world", sharingStyle:      "export", starterKeys: [".nlogox", ".csv"], starterMode: "internal" }
  , "segregation":   { hasLoadableWork:  true, isSplit:  true, name:   "segregation", sharingStyle:      "export", starterKeys:                  [], starterMode:     "none" }
  };

export { activities, type Activity };
