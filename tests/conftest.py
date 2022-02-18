import os
from functools import partial
from pathlib import Path
from typing import Callable

import pytest

MODULE_DIR = Path(__file__).absolute().parent
# テストデータ用ディレクトリ
TEST_DATA_DIR = MODULE_DIR / "../test_files"
# テスト結果データ用ディレクトリ
TEST_RESULTS_DIR = MODULE_DIR / "../test_results"


@pytest.fixture(scope="session")
def test_data_dir() -> Path:
    return TEST_DATA_DIR


@pytest.fixture(scope="session")
def test_result_dir() -> Path:
    return TEST_RESULTS_DIR


@pytest.fixture(scope="module")
def savedir(request: pytest.FixtureRequest) -> Path:
    """テストモジュール固有のディレクトリ"""
    module_name = request.node.module.__name__
    savename = TEST_RESULTS_DIR / module_name
    # ディレクトリ作成しておく
    os.makedirs(savename.parent, exist_ok=True)
    return savename

@pytest.fixture()
def savename_with_suffix(request: pytest.FixtureRequest) -> Callable:
    """テスト名を含むファイルパス"""
    def _savename_with_suffix(suffix: str, _request) -> Path:
        module_name = _request.node.module.__name__
        test_name = _request.node.name + suffix
        savename = TEST_RESULTS_DIR / module_name / test_name
        # ディレクトリ作成しておく
        os.makedirs(savename.parent, exist_ok=True)
        # ファイルが存在していたら削除
        if savename.exists():
            os.remove(savename)
        return savename

    return partial(_savename_with_suffix, _request=request)
