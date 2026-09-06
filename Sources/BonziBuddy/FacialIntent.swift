import simd

// Automatic expression channels; user controls are composed afterward.
// Smile is an offset from the user's neutral setting, so routine returns preserve it.
struct FacialIntent {
    var jawOpening:Float=0
    var eyeClosure:Float=0
    var gaze=SIMD2<Float>.zero
    var smileOffset:Float=0
    var mouthPucker:Float=0
    var individualEyeClosure=SIMD2<Float>.zero // Character left, right.
    func blended(to other:FacialIntent,amount:Float)->FacialIntent {
        FacialIntent(jawOpening:jawOpening+(other.jawOpening-jawOpening)*amount,
                     eyeClosure:eyeClosure+(other.eyeClosure-eyeClosure)*amount,
                     gaze:gaze+(other.gaze-gaze)*amount,
                     smileOffset:smileOffset+(other.smileOffset-smileOffset)*amount,
                     mouthPucker:mouthPucker+(other.mouthPucker-mouthPucker)*amount,
                     individualEyeClosure:individualEyeClosure+(other.individualEyeClosure-individualEyeClosure)*amount)
    }
    func distance(to other:FacialIntent)->Float {
        max(length(individualEyeClosure-other.individualEyeClosure),max(abs(mouthPucker-other.mouthPucker),max(abs(jawOpening-other.jawOpening),max(abs(eyeClosure-other.eyeClosure),max(length(gaze-other.gaze),abs(smileOffset-other.smileOffset))))))
    }
}
