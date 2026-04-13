; ModuleID = 'hello.c'
source_filename = "hello.c"
target datalayout = "e-m:e-p:64:64-i64:64-i128:128-n64-S128"
target triple = "riscv64-unknown-linux-gnu"

; Function Attrs: noinline nounwind optnone
define dso_local void @_start() #0 {
  %1 = alloca i32, align 4
  %2 = alloca i32, align 4
  %3 = alloca i32, align 4
  %4 = alloca i64, align 8
  %5 = alloca i64, align 8
  store volatile i32 5, i32* %1, align 4
  store volatile i32 10, i32* %2, align 4
  %6 = load volatile i32, i32* %1, align 4
  %7 = load volatile i32, i32* %2, align 4
  %8 = add nsw i32 %6, %7
  store volatile i32 %8, i32* %3, align 4
  store i64 0, i64* %4, align 8
  store i64 93, i64* %5, align 8
  %9 = load i64, i64* %4, align 8
  %10 = load i64, i64* %5, align 8
  call void asm sideeffect "ecall", "{x10},{x17}"(i64 %9, i64 %10) #1, !srcloc !7
  ret void
}

attributes #0 = { noinline nounwind optnone "frame-pointer"="all" "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-features"="+64bit,+a,+c,+d,+f,+m" }
attributes #1 = { nounwind }

!llvm.module.flags = !{!0, !1, !2, !3, !4, !5}
!llvm.ident = !{!6}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 1, !"target-abi", !"lp64d"}
!2 = !{i32 7, !"PIC Level", i32 2}
!3 = !{i32 7, !"PIE Level", i32 2}
!4 = !{i32 7, !"frame-pointer", i32 2}
!5 = !{i32 1, !"SmallDataLimit", i32 8}
!6 = !{!"Ubuntu clang version 14.0.0-1ubuntu1.1"}
!7 = !{i64 295}
