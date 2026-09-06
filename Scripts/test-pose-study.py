#!/usr/bin/env python3
"""Input-contract regression checks; does not require Metal or launch the app."""
import importlib.util
import copy
from pathlib import Path
import unittest

module_spec = importlib.util.spec_from_file_location('pose_study', Path(__file__).with_name('study-hand-pose.py'))
study = importlib.util.module_from_spec(module_spec)
module_spec.loader.exec_module(study)
validate = study.validate_spec


class StudyInputs(unittest.TestCase):
    def setUp(self):
        self.spec = {'action': 'Hug', 'time': .8, 'pose': {'left': {'palmContact': [.4, .17, .28]}}, 'variables': [['left', 'palmContact', 2, .2, .4, .02]]}

    def test_valid_single_and_multiple_samples(self):
        validate(self.spec, 2)
        self.spec.pop('time')
        self.spec['times'] = [.8, 1.32]
        validate(self.spec, 1)

    def test_invalid_times(self):
        for times in ([], [float('nan')], [-1], [True], '0.8'):
            spec = copy.deepcopy(self.spec)
            spec.pop('time')
            spec['times'] = times
            with self.subTest(times=times), self.assertRaises(ValueError):
                validate(spec, 1)

    def test_invalid_search_variables(self):
        for variable in (['left', 'palmContact', 3, .2, .4, .02], ['left', 'palmContact', 2, .4, .2, .02], ['left', 'palmContact', 2, .2, .4, 0], ['left', 'palmContact', 2, .3, .4, .02], ['right', 'palmContact', 2, .2, .4, .02]):
            self.spec['variables'] = [variable]
            with self.subTest(variable=variable), self.assertRaises(ValueError):
                validate(self.spec, 1)

    def test_unknown_field_and_partial_orientation(self):
        for patch in ({'plamContact': [0, 0, 0]}, {'fingers': [1, 0, 0]}, {'grip': 2}):
            self.spec['pose']['left'] = patch
            with self.subTest(patch=patch), self.assertRaises(ValueError):
                validate(self.spec, 1)

    def test_nonpositive_passes(self):
        with self.assertRaises(ValueError):
            validate(self.spec, 0)


if __name__ == '__main__':
    unittest.main()
