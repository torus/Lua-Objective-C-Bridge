%module cg

%{
#import <CoreGraphics/CGAffineTransform.h>
#import "LuaBridge.h"

int CGAffineTransform_to_NSValue (lua_State *L)
{
  int SWIG_arg = 0;
  struct CGAffineTransform *arg1 = (struct CGAffineTransform *) 0 ;

  if(!SWIG_isptrtype(L,1)) SWIG_fail_arg("CGAffineTransformWrap",1,"struct CGAffineTransform *");
  
  if (!SWIG_IsOK(SWIG_ConvertPtr(L,1,(void**)&arg1,SWIGTYPE_p_CGAffineTransform,0))){
    SWIG_fail_ptr("CGAffineTransformWrap",1,SWIGTYPE_p_CGAffineTransform);
  }
  {
  NSValue *val = [NSValue valueWithCGAffineTransform:*arg1];
  luabridge_push_object(L, val); SWIG_arg ++;

  return SWIG_arg;
  }

fail:
  lua_error(L);
  return SWIG_arg;
}

%}

typedef float CGFloat;

typedef struct CGAffineTransform CGAffineTransform;

struct CGAffineTransform {
  CGFloat a, b, c, d;
  CGFloat tx, ty;
};

const CGAffineTransform CGAffineTransformIdentity;

%native(CGAffineTransformWrap) int CGAffineTransform_to_NSValue (lua_State *L);

CGAffineTransform CGAffineTransformMake(CGFloat a, CGFloat b,
  CGFloat c, CGFloat d, CGFloat tx, CGFloat ty);

CGAffineTransform CGAffineTransformMakeTranslation(CGFloat tx, CGFloat ty);

CGAffineTransform CGAffineTransformMakeScale(CGFloat sx, CGFloat sy);

CGAffineTransform CGAffineTransformMakeRotation(CGFloat angle);

bool CGAffineTransformIsIdentity(CGAffineTransform t);

CGAffineTransform CGAffineTransformTranslate(CGAffineTransform t,
  CGFloat tx, CGFloat ty);

CGAffineTransform CGAffineTransformScale(CGAffineTransform t,
  CGFloat sx, CGFloat sy);

CGAffineTransform CGAffineTransformRotate(CGAffineTransform t, CGFloat angle);

CGAffineTransform CGAffineTransformInvert(CGAffineTransform t);

CGAffineTransform CGAffineTransformConcat(CGAffineTransform t1,
  CGAffineTransform t2);

bool CGAffineTransformEqualToTransform(CGAffineTransform t1,
  CGAffineTransform t2);

CGPoint CGPointApplyAffineTransform(CGPoint point,
  CGAffineTransform t);

CGSize CGSizeApplyAffineTransform(CGSize size, CGAffineTransform t);

CGRect CGRectApplyAffineTransform(CGRect rect, CGAffineTransform t);
