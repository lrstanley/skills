#!/usr/bin/env -S uv -q run --script
# /// script
# requires-python = ">=3.13"
# dependencies = ["click", "jsonschema", "ruamel.yaml", "wcmatch"]
# ///

from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

import click
import jsonschema
from ruamel.yaml import YAML
from ruamel.yaml.error import YAMLError
from wcmatch import glob as wglob

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent.parent
DEFAULT_CONFIG = REPO_ROOT / "remotes.yaml"
SCHEMA_PATH = REPO_ROOT / ".github" / "schemas" / "remotes.json"

GLOB_FLAGS = wglob.GLOBSTAR | wglob.BRACE | wglob.EXTGLOB


def load_schema() -> dict[str, Any]:
    with SCHEMA_PATH.open(encoding="utf-8") as handle:
        return json.load(handle)


def load_config(config_path: Path) -> tuple[Any, YAML]:
    yaml = YAML(typ="rt")
    yaml.preserve_quotes = True
    yaml.default_flow_style = False
    yaml.indent(mapping=2, sequence=4, offset=2)
    with config_path.open(encoding="utf-8") as handle:
        data = yaml.load(handle)
    if data is None:
        data = {"remotes": []}
    return data, yaml


def validate_config(data: dict[str, Any], schema: dict[str, Any]) -> None:
    jsonschema.validate(instance=data, schema=schema)


def validate_patch_paths(data: dict[str, Any]) -> None:
    for remote in data.get("remotes", []):
        for patch in remote.get("patches") or []:
            patch_path = REPO_ROOT / patch
            if not patch_path.is_file():
                raise click.ClickException(f"patch file not found: {patch}")


def resolve_head_sha(git_url: str) -> str:
    result = subprocess.run(
        ["git", "ls-remote", "--symref", git_url, "HEAD"],
        capture_output=True,
        text=True,
        check=True,
    )
    for line in result.stdout.splitlines():
        if line.endswith("\tHEAD") and not line.startswith("ref:"):
            sha = line.split("\t", 1)[0].strip()
            if re.fullmatch(r"[0-9a-f]{40}", sha):
                return sha
    raise click.ClickException(f"unable to resolve HEAD for {git_url}")


def update_commit_shas(data: dict[str, Any]) -> None:
    for remote in data.get("remotes", []):
        remote["commit_sha"] = resolve_head_sha(remote["git_url"])


def write_config(config_path: Path, data: dict[str, Any], yaml: YAML) -> None:
    with config_path.open("w", encoding="utf-8") as handle:
        yaml.dump(data, handle)


def clone_at_commit(git_url: str, commit_sha: str, dest: Path) -> None:
    subprocess.run(
        ["git", "clone", "--depth=1", git_url, str(dest)],
        check=True,
        capture_output=True,
        text=True,
    )
    checkout = subprocess.run(
        ["git", "checkout", commit_sha],
        cwd=dest,
        capture_output=True,
        text=True,
    )
    if checkout.returncode != 0:
        subprocess.run(
            ["git", "fetch", "--depth=1", "origin", commit_sha],
            cwd=dest,
            check=True,
            capture_output=True,
            text=True,
        )
        subprocess.run(
            ["git", "checkout", commit_sha],
            cwd=dest,
            check=True,
            capture_output=True,
            text=True,
        )


def copy_clone(source: Path, dest: Path) -> None:
    if dest.exists():
        shutil.rmtree(dest)
    shutil.copytree(
        source,
        dest,
        symlinks=True,
        ignore=shutil.ignore_patterns(),
        dirs_exist_ok=False,
    )


def apply_patches(work_dir: Path, patches: list[str]) -> None:
    for patch in patches:
        patch_path = REPO_ROOT / patch
        check = subprocess.run(
            ["git", "apply", "--check", str(patch_path)],
            cwd=work_dir,
            capture_output=True,
            text=True,
        )
        if check.returncode != 0:
            detail = check.stderr.strip() or check.stdout.strip()
            raise click.ClickException(
                f"patch check failed for {patch}: {detail}"
            )
        apply = subprocess.run(
            ["git", "apply", str(patch_path)],
            cwd=work_dir,
            capture_output=True,
            text=True,
        )
        if apply.returncode != 0:
            detail = apply.stderr.strip() or apply.stdout.strip()
            raise click.ClickException(
                f"patch apply failed for {patch}: {detail}"
            )


def top_level_dest_dirs(file_includes: list[dict[str, str]]) -> set[str]:
    dirs: set[str] = set()
    for entry in file_includes:
        dest = entry["dest"].strip("/")
        if not dest:
            continue
        top_level = dest.split("/", 1)[0]
        if top_level:
            dirs.add(top_level)
    return dirs


def delete_dest_dirs(repo_root: Path, dest_dirs: set[str]) -> None:
    for dirname in sorted(dest_dirs):
        target = repo_root / dirname
        if target.exists():
            shutil.rmtree(target)


def is_tree_glob(src: str) -> bool:
    return src.endswith("/**")


def tree_glob_prefix(src: str) -> str:
    return src[: -len("/**")].rstrip("/") + "/"


def is_single_file_pattern(src: str) -> bool:
    return "*" not in src


def is_excluded(rel_path: str, file_excludes: list[dict[str, str]]) -> bool:
    for entry in file_excludes:
        if wglob.globmatch(rel_path, entry["src"], flags=GLOB_FLAGS):
            return True
    return False


def iter_matched_paths(
    clone_root: Path,
    src: str,
    file_excludes: list[dict[str, str]] | None = None,
) -> list[Path]:
    excludes = file_excludes or []
    if is_single_file_pattern(src):
        candidate = clone_root / src
        if candidate.is_file():
            rel = candidate.relative_to(clone_root).as_posix()
            if not is_excluded(rel, excludes):
                return [candidate]
        return []

    matches: list[Path] = []
    for path in clone_root.rglob("*"):
        if not path.is_file():
            continue
        rel = path.relative_to(clone_root).as_posix()
        if is_excluded(rel, excludes):
            continue
        if wglob.globmatch(rel, src, flags=GLOB_FLAGS):
            matches.append(path)
    return sorted(matches)


def copy_file_preserve_mode(source: Path, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, dest)


def sync_file_filter(
    clone_root: Path,
    repo_root: Path,
    src: str,
    dest: str,
    file_excludes: list[dict[str, str]] | None = None,
) -> None:
    if is_tree_glob(src):
        prefix = tree_glob_prefix(src)
        dest_base = dest.rstrip("/")
        for matched in iter_matched_paths(clone_root, src, file_excludes):
            rel = matched.relative_to(clone_root).as_posix()
            if not rel.startswith(prefix):
                continue
            suffix = rel[len(prefix) :]
            target = repo_root / dest_base / suffix
            copy_file_preserve_mode(matched, target)
        return

    if is_single_file_pattern(src):
        matched = iter_matched_paths(clone_root, src, file_excludes)
        if not matched:
            raise click.ClickException(f"no files matched src pattern: {src}")
        copy_file_preserve_mode(matched[0], repo_root / dest)
        return

    dest_base = dest.rstrip("/")
    for matched in iter_matched_paths(clone_root, src, file_excludes):
        rel = matched.relative_to(clone_root).as_posix()
        target = repo_root / dest_base / rel
        copy_file_preserve_mode(matched, target)


def sync_remote(
    remote: dict[str, Any],
    repo_root: Path,
    clone_cache: dict[tuple[str, str], Path],
    temp_dirs: list[Path],
) -> None:
    name = remote["name"]
    git_url = remote["git_url"]
    commit_sha = remote["commit_sha"]
    patches = remote.get("patches") or []
    file_includes = remote["file_includes"]
    file_excludes = remote.get("file_excludes") or []

    cache_key = (git_url, commit_sha)
    if cache_key not in clone_cache:
        cache_dir = Path(tempfile.mkdtemp(prefix="remote-clone-"))
        temp_dirs.append(cache_dir)
        click.echo(f"[{name}] cloning {git_url} @ {commit_sha[:8]}")
        clone_at_commit(git_url, commit_sha, cache_dir)
        clone_cache[cache_key] = cache_dir

    work_dir = Path(tempfile.mkdtemp(prefix=f"remote-work-{name}-"))
    temp_dirs.append(work_dir)
    copy_clone(clone_cache[cache_key], work_dir)

    if patches:
        click.echo(f"[{name}] applying {len(patches)} patch(es)")
        apply_patches(work_dir, patches)

    dest_dirs = top_level_dest_dirs(file_includes)
    delete_dest_dirs(repo_root, dest_dirs)

    for entry in file_includes:
        src = entry["src"]
        dest = entry["dest"]
        click.echo(f"[{name}] syncing {src} -> {dest}")
        sync_file_filter(work_dir, repo_root, src, dest, file_excludes)


def cleanup_temp_dirs(temp_dirs: list[Path]) -> None:
    for path in temp_dirs:
        if path.exists():
            shutil.rmtree(path, ignore_errors=True)


@click.command()
@click.option(
    "--config",
    "config_path",
    type=click.Path(path_type=Path, exists=True, dir_okay=False),
    default=DEFAULT_CONFIG,
    show_default=True,
    help="Path to remotes.yaml",
)
@click.option(
    "--update",
    is_flag=True,
    help="Resolve default branch HEAD and rewrite commit_sha in config",
)
@click.option(
    "--filter",
    "remote_filter",
    type=str,
    default=None,
    help="Process only the remote with this name",
)
def main(
    config_path: Path,
    update: bool,
    remote_filter: str | None,
) -> None:
    repo_root = REPO_ROOT
    schema = load_schema()
    data, yaml = load_config(config_path)

    if not isinstance(data, dict):
        raise click.ClickException("config root must be a mapping")

    validate_config(data, schema)
    validate_patch_paths(data)

    remotes: list[dict[str, Any]] = data.get("remotes", [])
    if remote_filter is not None:
        remotes = [remote for remote in remotes if remote["name"] == remote_filter]
        if not remotes:
            raise click.ClickException(f"no remote named {remote_filter!r}")

    if update:
        click.echo("updating commit_sha values")
        update_data = data
        if remote_filter is not None:
            for remote in update_data.get("remotes", []):
                if remote["name"] == remote_filter:
                    remote["commit_sha"] = resolve_head_sha(remote["git_url"])
        else:
            update_commit_shas(update_data)
        write_config(config_path, update_data, yaml)
        click.echo(f"wrote {config_path}")
        data, yaml = load_config(config_path)
        remotes = data.get("remotes", [])
        if remote_filter is not None:
            remotes = [remote for remote in remotes if remote["name"] == remote_filter]

    if not remotes:
        click.echo("no remotes to sync")
        return

    clone_cache: dict[tuple[str, str], Path] = {}
    temp_dirs: list[Path] = []

    try:
        for remote in remotes:
            sync_remote(remote, repo_root, clone_cache, temp_dirs)
    except click.ClickException:
        cleanup_temp_dirs(temp_dirs)
        raise
    except subprocess.CalledProcessError as exc:
        cleanup_temp_dirs(temp_dirs)
        detail = exc.stderr or exc.stdout or str(exc)
        if isinstance(detail, bytes):
            detail = detail.decode()
        raise click.ClickException(f"git command failed: {detail.strip()}") from exc
    finally:
        cleanup_temp_dirs(temp_dirs)

    click.echo("sync complete")


if __name__ == "__main__":
    try:
        main(standalone_mode=False)
    except click.ClickException as exc:
        click.echo(f"error: {exc}", err=True)
        sys.exit(1)
    except YAMLError as exc:
        click.echo(f"error: invalid yaml in config: {exc}", err=True)
        sys.exit(1)
