#ifndef BUILDING_NODE_EXTENSION
#define BUILDING_NODE_EXTENSION
#endif  // BUILDING_NODE_EXTENSION
#include <node.h>
#include "nan.h"

using namespace v8;

NAN_METHOD(Clone) {
  NanScope();
  Handle<Value>arg = args[0];
  if (arg->IsObject()) {
    Handle<Object>obj = Handle<Object>::Cast(arg);
    NanReturnValue(obj->Clone());
  }
  NanReturnValue(arg);
}

void Init(Handle<Object> target) {
  target->Set(NanNew<String>("clone"),
      NanNew<FunctionTemplate>(Clone)->GetFunction());
}

NODE_MODULE(clone, Init)
