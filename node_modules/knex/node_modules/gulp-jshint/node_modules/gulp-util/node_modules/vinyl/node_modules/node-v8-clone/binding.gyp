{
  "targets": [
    {
      "target_name": "clone",
      "sources": [ "src/clone.cc" ],
      "include_dirs": [
        "<!(node -e \"require('nan')\")"
      ]
    }
  ]
}