from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_current_user
from ..models import Conversation, Message, User
from ..schemas import ConversationStartIn, MessageIn

router = APIRouter(prefix="/api/chat", tags=["chat"])


def _is_participant(conversation: Conversation, user: User) -> bool:
    return user.id in (conversation.owner_id, conversation.finder_id)


def _peer_id(conversation: Conversation, user: User) -> str:
    return conversation.finder_id if conversation.owner_id == user.id else conversation.owner_id


def serialize_conversation(db: Session, conversation: Conversation, user: User) -> dict[str, Any]:
    peer = db.get(User, _peer_id(conversation, user))
    last = (
        db.query(Message)
        .filter(Message.conversation_id == conversation.id)
        .order_by(Message.created_at.desc())
        .first()
    )
    unread = (
        db.query(func.count(Message.id))
        .filter(
            Message.conversation_id == conversation.id,
            Message.sender_id != user.id,
            Message.read.is_(False),
        )
        .scalar()
    )
    return {
        "id": conversation.id,
        "peer_id": peer.id if peer else "",
        "peer_name": peer.full_name if peer else "Utilisateur",
        "peer_role": peer.role if peer else "",
        "peer_photo": peer.profile_photo if peer else "",
        "subject": conversation.subject,
        "last_message": last.body if last else "",
        "last_message_at": last.created_at.isoformat() if last and last.created_at else None,
        "unread_count": int(unread or 0),
        "loss_id": conversation.loss_id,
        "find_id": conversation.find_id,
    }


def serialize_message(message: Message) -> dict[str, Any]:
    return {
        "id": message.id,
        "conversation_id": message.conversation_id,
        "sender_id": message.sender_id,
        "body": message.body,
        "read": message.read,
        "created_at": message.created_at.isoformat() if message.created_at else None,
    }


@router.get("/peers")
def list_peers(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    wanted_role = "finder" if current_user.active_profile == "owner" else "owner"
    peers = (
        db.query(User)
        .filter(
            User.id != current_user.id,
            User.is_blocked.is_(False),
            User.is_admin.is_(False),
            or_(User.role == wanted_role, User.active_profile == wanted_role),
        )
        .order_by(User.created_at.desc())
        .all()
    )
    return {
        "role_filter": wanted_role,
        "items": [
            {
                "id": peer.id,
                "first_name": peer.first_name,
                "last_name": peer.last_name,
                "email": peer.email,
                "phone": peer.phone,
                "role": peer.role,
                "profile_photo": peer.profile_photo,
                "average_rating": peer.average_rating,
            }
            for peer in peers
        ],
        "count": len(peers),
    }


@router.post("/conversations", status_code=status.HTTP_201_CREATED)
def start_conversation(
    payload: ConversationStartIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    peer = db.get(User, payload.peer_id)
    if peer is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Utilisateur introuvable.")
    if peer.is_blocked:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cet utilisateur est bloqué.",
        )

    if current_user.active_profile == "owner":
        owner_id, finder_id = current_user.id, peer.id
    else:
        owner_id, finder_id = peer.id, current_user.id

    existing = (
        db.query(Conversation)
        .filter(
            Conversation.owner_id == owner_id,
            Conversation.finder_id == finder_id,
            Conversation.subject == (payload.subject or ""),
        )
        .first()
    )
    if existing:
        return serialize_conversation(db, existing, current_user)

    conversation = Conversation(
        owner_id=owner_id,
        finder_id=finder_id,
        subject=payload.subject or f"Conversation avec {peer.full_name}",
        loss_id=payload.loss_id,
        find_id=payload.find_id,
    )
    db.add(conversation)
    db.commit()
    db.refresh(conversation)
    return serialize_conversation(db, conversation, current_user)


@router.get("/conversations")
def list_conversations(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    rows = (
        db.query(Conversation)
        .filter(
            or_(
                Conversation.owner_id == current_user.id,
                Conversation.finder_id == current_user.id,
            )
        )
        .order_by(Conversation.updated_at.desc())
        .all()
    )
    items = [serialize_conversation(db, row, current_user) for row in rows]
    items.sort(key=lambda item: item["last_message_at"] or "", reverse=True)
    return {"items": items, "count": len(items)}


@router.get("/conversations/{conversation_id}")
def conversation_detail(
    conversation_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    conversation = db.get(Conversation, conversation_id)
    if conversation is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Conversation introuvable.")
    if not _is_participant(conversation, current_user):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Accès refusé.")
    return serialize_conversation(db, conversation, current_user)


@router.get("/conversations/{conversation_id}/messages")
def list_messages(
    conversation_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    conversation = db.get(Conversation, conversation_id)
    if conversation is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Conversation introuvable.")
    if not _is_participant(conversation, current_user):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Accès refusé.")

    db.query(Message).filter(
        Message.conversation_id == conversation_id,
        Message.sender_id != current_user.id,
        Message.read.is_(False),
    ).update({"read": True}, synchronize_session=False)
    db.commit()

    rows = (
        db.query(Message)
        .filter(Message.conversation_id == conversation_id)
        .order_by(Message.created_at.asc())
        .all()
    )
    return {
        "items": [serialize_message(row) for row in rows],
        "count": len(rows),
        "conversation": serialize_conversation(db, conversation, current_user),
    }


@router.post("/conversations/{conversation_id}/messages", status_code=status.HTTP_201_CREATED)
def send_message(
    conversation_id: str,
    payload: MessageIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    conversation = db.get(Conversation, conversation_id)
    if conversation is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Conversation introuvable.")
    if not _is_participant(conversation, current_user):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Accès refusé.")

    message = Message(
        conversation_id=conversation_id,
        sender_id=current_user.id,
        body=payload.body.strip(),
    )
    db.add(message)
    db.commit()
    db.refresh(message)
    return serialize_message(message)
