import simd

// Original WriteOnce lasts 1.45s; WriteOnceAgain lasts 1.20s. Both settle into
// the same paused writing performance, retaining the pad and pencil.
enum WriteSingleRoutine {
    static let once=definition(strokeDuration:1.45)
    static let again=definition(strokeDuration:1.20)
    private static func definition(strokeDuration:Double)->RoutineDefinition {
        let strokeStart=1.90,strokeEnd=strokeStart+strokeDuration
        let pauseOffset=strokeDuration
        let pause=WritePauseRoutine.continuation
        let continuation=RoutineContinuation(family:.writing,entryElapsed:strokeStart,
            acceptsFrom:0..<(pause.acceptsFrom.upperBound+pauseOffset),delay:{t in
                t<strokeEnd ? strokeEnd-t:pause.delay(t-pauseOffset)
            },exitElapsed:{t in
                guard t>=strokeEnd,let exit=pause.exitElapsed(t-pauseOffset) else {return nil}
                return exit+pauseOffset
            })
        return RoutineDefinition(duration:WritePauseRoutine.duration+pauseOffset,changesFacing:true,
            holdRange:(WritePauseRoutine.holdRange.lowerBound+pauseOffset)..<(WritePauseRoutine.holdRange.upperBound+pauseOffset),
            handoffPolicy:.finishRoutine,continuation:continuation,sample:{t in
                if t<strokeStart {return WriteRoutine.sample(at:t)}
                if t<strokeEnd {
                    return WriteRoutine.sample(at:4.30+(t-strokeStart)*1.20/strokeDuration)
                }
                return WritePauseRoutine.sample(at:t-pauseOffset)
            })
    }
}
