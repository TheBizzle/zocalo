import tseslint  from "@typescript-eslint/eslint-plugin";
import tsparser  from "@typescript-eslint/parser";
import vueParser from "vue-eslint-parser";
import vuePlugin from "eslint-plugin-vue";

const bizzleRules =
  { "block-scoped-var":                                                "error"
  , "camelcase":                                                       "error"
  , "default-case":                                                    "error"
  , "default-case-last":                                               "error"
  , "eqeqeq":                                                          ["error", "always"]
  , "func-names":                                                      ["error", "always"]
  , "multiline-comment-style":                                         ["error", "separate-lines"]
  , "new-cap":                                                         "error"
  , "no-bitwise":                                                      ["error", { allow: [">>>", ">>", "<<"] }]
  , "no-caller":                                                       "error"
  , "no-continue":                                                     "error"
  , "no-eq-null":                                                      "error"
  , "no-eval":                                                         "error"
  , "no-extend-native":                                                "error"
  , "no-extra-bind":                                                   "error"
  , "no-extra-label":                                                  "error"
  , "no-floating-decimal":                                             "error"
  , "no-implicit-coercion":                                            "error"
  , "no-implicit-globals":                                             ["error", { lexicalBindings: true }]
  , "no-iterator":                                                     "error"
  , "no-label-var":                                                    "error"
  , "no-labels":                                                       "error"
  , "no-lone-blocks":                                                  "error"
  , "no-multi-assign":                                                 "error"
  , "no-new":                                                          "error"
  , "no-new-func":                                                     "error"
  , "no-new-object":                                                   "error"
  , "no-new-wrappers":                                                 "error"
  , "no-octal-escape":                                                 "error"
  , "no-param-reassign":                                               "error"
  , "no-proto":                                                        "error"
  , "no-return-assign":                                                ["error", "always"]
  , "no-return-await":                                                 "error"
  , "no-script-url":                                                   "error"
  , "no-sequences":                                                    ["error", { allowInParentheses: false }]
  , "no-throw-literal":                                                "error"
  , "no-unneeded-ternary":                                             "error"
  , "no-useless-call":                                                 "error"
  , "no-useless-computed-key":                                         "error"
  , "no-useless-concat":                                               "error"
  , "no-useless-rename":                                               "error"
  , "no-useless-return":                                               "error"
  , "no-var":                                                          "error"
  , "no-void":                                                         ["error", { allowAsStatement: true }]
  , "no-with":                                                         "error"
  , "object-shorthand":                                                "error"
  , "one-var":                                                         ["error", "never"]
  , "one-var-declaration-per-line":                                    ["error", "always"]
  , "prefer-arrow-callback":                                           "error"
  , "prefer-const":                                                    "error"
  , "prefer-exponentiation-operator":                                  "error"
  , "prefer-numeric-literals":                                         "error"
  , "prefer-object-spread":                                            "error"
  , "prefer-regex-literals":                                           ["error", { disallowRedundantWrapping: true }]
  , "prefer-rest-params":                                              "error"
  , "prefer-spread":                                                   "error"
  , "prefer-template":                                                 "error"
  , "quotes":                                                          ["error", "double"]
  , "radix":                                                           ["error", "as-needed"]
  , "semi":                                                            ["error", "always"]
  , "spaced-comment":                                                  ["error", "always"]
  , "yoda":                                                            ["error", "never"]
  , "arrow-spacing":                                                   "error"
  , "block-spacing":                                                   ["error", "always"]
  , "brace-style":                                                     ["error", "1tbs", { allowSingleLine: true }]
  , "comma-style":                                                     ["error", "first"]
  , "dot-location":                                                    "error"
  , "eol-last":                                                        "error"
  , "key-spacing":                                                     ["error", { mode: "minimum" }]
  , "keyword-spacing":                                                 "error"
  , "linebreak-style":                                                 ["error", "unix"]
  , "max-len":                                                         ["error", { code: 105, ignoreComments: true, ignoreRegExpLiterals: true, ignoreStrings: true, ignoreTemplateLiterals: true, tabWidth: 2 }]
  , "max-statements-per-line":                                         ["error", { max: 10 }]
  , "no-tabs":                                                         "error"
  , "no-trailing-spaces":                                              "error"
  , "object-curly-spacing":                                            ["error", "always"]
  , "rest-spread-spacing":                                             ["error", "never"]
  , "semi-spacing":                                                    ["error", { before: false, after: true }]
  , "semi-style":                                                      "error"
  , "space-unary-ops":                                                 ["error", { words: true, nonwords: false, overrides: { typeof: false } }]
  , "switch-colon-spacing":                                            "error"
  , "unicode-bom":                                                     "error"
  , "wrap-iife":                                                       ["error", "inside"]
  , "no-dupe-class-members":                                           "off"
  , "no-redeclare":                                                    "off"
  , "no-unused-vars":                                                  "off"
  , "@typescript-eslint/adjacent-overload-signatures":                 "off"
  , "@typescript-eslint/array-type":                                   ["error", { "default": "generic" }]
  , "@typescript-eslint/await-thenable":                               "error"
  , "@typescript-eslint/ban-ts-comment":                               "error"
  , "@typescript-eslint/ban-tslint-comment":                           "off"
  , "@typescript-eslint/class-literal-property-style":                 ["error", "getters"]
  , "@typescript-eslint/class-methods-use-this":                       "error"
  , "@typescript-eslint/consistent-generic-constructors":              ["error", "constructor"]
  , "@typescript-eslint/consistent-indexed-object-style":              ["error", "record"]
  , "@typescript-eslint/consistent-return":                            ["error"]
  , "@typescript-eslint/consistent-type-assertions":                   ["error", { assertionStyle: "as", objectLiteralTypeAssertions: "allow" }]
  , "@typescript-eslint/consistent-type-definitions":                  ["error", "type"]
  , "@typescript-eslint/consistent-type-exports":                      "error"
  , "@typescript-eslint/consistent-type-imports":                      "error"
  , "@typescript-eslint/default-param-last":                           "error"
  , "@typescript-eslint/dot-notation":                                 "error"
  , "@typescript-eslint/explicit-function-return-type":                "error"
  , "@typescript-eslint/explicit-member-accessibility":                "error"
  , "@typescript-eslint/explicit-module-boundary-types":               "error"
  , "@typescript-eslint/init-declarations":                            ["error", "always"]
  , "@typescript-eslint/member-ordering":                              "off"
  , "@typescript-eslint/method-signature-style":                       ["error", "property"]
  , "@typescript-eslint/naming-convention":                            ["error", { "selector": ["enumMember"], "format": ["PascalCase"] }]
  , "@typescript-eslint/no-array-delete":                              "error"
  , "@typescript-eslint/no-base-to-string":                            "error"
  , "@typescript-eslint/no-confusing-non-null-assertion":              "error"
  , "@typescript-eslint/no-confusing-void-expression":                 "error"
  , "@typescript-eslint/no-duplicate-enum-values":                     "error"
  , "@typescript-eslint/no-duplicate-type-constituents":               "error"
  , "@typescript-eslint/no-dynamic-delete":                            "error"
  , "@typescript-eslint/no-empty-object-type":                         "error"
  , "@typescript-eslint/no-explicit-any":                              "error"
  , "@typescript-eslint/no-extraneous-class":                          "error"
  , "@typescript-eslint/no-extra-non-null-assertion":                  "error"
  , "@typescript-eslint/no-floating-promises":                         "error"
  , "@typescript-eslint/no-for-in-array":                              "error"
  , "@typescript-eslint/no-implied-eval":                              "error"
  , "@typescript-eslint/no-import-type-side-effects":                  "error"
  , "@typescript-eslint/no-inferrable-types":                          "off"
  , "@typescript-eslint/no-invalid-void-type":                         "error"
  , "@typescript-eslint/no-loop-func":                                 "error"
  , "@typescript-eslint/no-meaningless-void-operator":                 "error"
  , "@typescript-eslint/no-misused-new":                               "error"
  , "@typescript-eslint/no-misused-promises":                          "error"
  , "@typescript-eslint/no-mixed-enums":                               "error"
  , "@typescript-eslint/no-namespace":                                 "error"
  , "@typescript-eslint/non-nullable-type-assertion-style":            "error"
  , "@typescript-eslint/no-non-null-asserted-nullish-coalescing":      "error"
  , "@typescript-eslint/no-non-null-asserted-optional-chain":          "error"
  , "@typescript-eslint/no-non-null-assertion":                        "off"
  , "@typescript-eslint/no-redundant-type-constituents":               "error"
  , "@typescript-eslint/no-require-imports":                           "error"
  , "@typescript-eslint/no-restricted-types":                          "off"
  , "@typescript-eslint/no-shadow":                                    ["error", { "builtinGlobals": false, "hoist": "all" }]
  , "@typescript-eslint/no-this-alias":                                "error"
  , "@typescript-eslint/no-unnecessary-boolean-literal-compare":       "error"
  , "@typescript-eslint/no-unnecessary-condition":                     "error"
  , "@typescript-eslint/no-unnecessary-parameter-property-assignment": "error"
  , "@typescript-eslint/no-unnecessary-qualifier":                     "error"
  , "@typescript-eslint/no-unnecessary-template-expression":           "error"
  , "@typescript-eslint/no-unnecessary-type-arguments":                "error"
  , "@typescript-eslint/no-unnecessary-type-assertion":                "error"
  , "@typescript-eslint/no-unnecessary-type-constraint":               "error"
  , "@typescript-eslint/no-unnecessary-type-parameters":               "error"
  , "@typescript-eslint/no-unsafe-argument":                           "error"
  , "@typescript-eslint/no-unsafe-assignment":                         "error"
  , "@typescript-eslint/no-unsafe-call":                               "error"
  , "@typescript-eslint/no-unsafe-declaration-merging":                "error"
  , "@typescript-eslint/no-unsafe-enum-comparison":                    "error"
  , "@typescript-eslint/no-unsafe-function-type":                      "error"
  , "@typescript-eslint/no-unsafe-member-access":                      "error"
  , "@typescript-eslint/no-unsafe-return":                             "error"
  , "@typescript-eslint/no-unsafe-unary-minus":                        "error"
  , "@typescript-eslint/no-unused-expressions":                        "error"
  , "@typescript-eslint/no-unused-vars":                               ["error", { "argsIgnorePattern": "^_.*$", "varsIgnorePattern": "^_.*$" }]
  , "@typescript-eslint/no-useless-empty-export":                      "error"
  , "@typescript-eslint/no-wrapper-object-types":                      "error"
  , "@typescript-eslint/parameter-properties":                         "off"
  , "@typescript-eslint/prefer-as-const":                              "error"
  , "@typescript-eslint/prefer-enum-initializers":                     "off"
  , "@typescript-eslint/prefer-find":                                  "error"
  , "@typescript-eslint/prefer-for-of":                                "error"
  , "@typescript-eslint/prefer-function-type":                         "error"
  , "@typescript-eslint/prefer-includes":                              "error"
  , "@typescript-eslint/prefer-literal-enum-member":                   "error"
  , "@typescript-eslint/prefer-namespace-keyword":                     "off"
  , "@typescript-eslint/prefer-nullish-coalescing":                    "error"
  , "@typescript-eslint/prefer-optional-chain":                        "error"
  , "@typescript-eslint/prefer-promise-reject-errors":                 "error"
  , "@typescript-eslint/prefer-readonly":                              "error"
  , "@typescript-eslint/prefer-readonly-parameter-types":              "off"
  , "@typescript-eslint/prefer-reduce-type-parameter":                 "error"
  , "@typescript-eslint/prefer-regexp-exec":                           "off"
  , "@typescript-eslint/prefer-return-this-type":                      "off"
  , "@typescript-eslint/prefer-string-starts-ends-with":               "error"
  , "@typescript-eslint/promise-function-async":                       "error"
  , "@typescript-eslint/require-array-sort-compare":                   "error"
  , "@typescript-eslint/restrict-plus-operands":                       ["error", { allowAny: false, allowBoolean: false, allowNullish: false, allowNumberAndString: false, allowRegExp: false }]
  , "@typescript-eslint/restrict-template-expressions":                "off"
  , "@typescript-eslint/strict-boolean-expressions":                   "error"
  , "@typescript-eslint/switch-exhaustiveness-check":                  "error"
  , "@typescript-eslint/triple-slash-reference":                       "error"
  , "@typescript-eslint/typedef":                                      ["off", { arrayDestructuring: false, arrowParameter: true, memberVariableDeclaration: true, objectDestructuring: false, parameter: true, propertyDeclaration: true, variableDeclaration: false, variableDeclarationIgnoreFunction: false }]
  , "@typescript-eslint/unbound-method":                               "error"
  , "@typescript-eslint/unified-signatures":                           "off"
  , "@typescript-eslint/use-unknown-in-catch-callback-variable":       "error"
  };

export default [

  // `.ts` files
  { plugins: {
      "@typescript-eslint": tseslint
    }
  , languageOptions: {
      ecmaVersion: 2022
    , parser:      tsparser
    , parserOptions: {
        project: true
      }
    , sourceType: "module"
    }
  , files: ["src/**/*.ts"]
  , rules: bizzleRules
  }

  // `.vue` files
, { plugins: {
      "@typescript-eslint": tseslint
    , vue:                  vuePlugin
    }
  , files: ["src/**/*.vue"]
  , languageOptions: {
      ecmaVersion: 2022
    , parser:      vueParser
    , parserOptions: {
        extraFileExtensions: [".vue"]
      , parser:              tsparser
      , project:             "./tsconfig.json"
      , sourceType:          "module"
      }
    }
  , rules: {
      ...vuePlugin.configs["flat/recommended"].rules
    , ...bizzleRules
    }
  }

];
