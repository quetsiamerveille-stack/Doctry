from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Any

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, Text, TypeDecorator
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .database import Base
from .timeutil import is_past, utcnow


class UTCDateTime(TypeDecorator):
    impl = DateTime
    cache_ok = True

    def process_bind_param(self, value: datetime | None, dialect: Any) -> datetime | None:
        if value is None:
            return None
        if value.tzinfo is not None:
            return value.astimezone(timezone.utc).replace(tzinfo=None)
        return value

    def process_result_value(self, value: datetime | None, dialect: Any) -> datetime | None:
        if value is None or value.tzinfo is not None:
            return value
        return value.replace(tzinfo=timezone.utc)


def new_id() -> str:
    return uuid.uuid4().hex


class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(UTCDateTime, default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(UTCDateTime, default=utcnow, onupdate=utcnow)


class User(Base, TimestampMixin):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    first_name: Mapped[str] = mapped_column(String(120), default="")
    last_name: Mapped[str] = mapped_column(String(120), default="")
    phone: Mapped[str] = mapped_column(String(40), default="")
    role: Mapped[str] = mapped_column(String(20), default="owner")
    active_profile: Mapped[str] = mapped_column(String(20), default="owner")
    profile_photo: Mapped[str] = mapped_column(String(500), default="")
    is_admin: Mapped[bool] = mapped_column(Boolean, default=False)
    is_blocked: Mapped[bool] = mapped_column(Boolean, default=False)
    wallet_balance: Mapped[float] = mapped_column(Float, default=0.0)
    last_rating_at: Mapped[datetime | None] = mapped_column(UTCDateTime, nullable=True)
    average_rating: Mapped[float] = mapped_column(Float, default=0.0)
    rating_count: Mapped[int] = mapped_column(Integer, default=0)

    documents: Mapped[list["Document"]] = relationship(back_populates="owner")
    notifications: Mapped[list["Notification"]] = relationship(back_populates="user")

    @property
    def full_name(self) -> str:
        return f"{self.first_name} {self.last_name}".strip() or self.email


class OtpCode(Base):
    __tablename__ = "otp_codes"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    email: Mapped[str] = mapped_column(String(255), index=True)
    code: Mapped[str] = mapped_column(String(12))
    purpose: Mapped[str] = mapped_column(String(30), default="login")
    context_ref: Mapped[str] = mapped_column(String(64), default="")
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    consumed: Mapped[bool] = mapped_column(Boolean, default=False)
    expires_at: Mapped[datetime] = mapped_column(UTCDateTime)
    created_at: Mapped[datetime] = mapped_column(UTCDateTime, default=utcnow)

    @property
    def is_valid(self) -> bool:
        return not self.consumed and not is_past(self.expires_at) and self.attempts < 5


class Document(Base, TimestampMixin):
    __tablename__ = "documents"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    owner_id: Mapped[str | None] = mapped_column(
        String(32), ForeignKey("users.id"), nullable=True, index=True
    )
    doc_type: Mapped[str] = mapped_column(String(60))
    holder_first_name: Mapped[str] = mapped_column(String(120), default="")
    holder_last_name: Mapped[str] = mapped_column(String(120), default="")
    holder_phone: Mapped[str] = mapped_column(String(40), default="")
    holder_email: Mapped[str] = mapped_column(String(255), default="")
    qr_id: Mapped[str] = mapped_column(String(64), unique=True, index=True, default="")
    qr_payload: Mapped[str] = mapped_column(Text, default="")
    qr_file: Mapped[str] = mapped_column(String(500), default="")
    image_file: Mapped[str] = mapped_column(String(500), default="")
    blurred_file: Mapped[str] = mapped_column(String(500), default="")
    fingerprint: Mapped[str] = mapped_column(Text, default="")
    status: Mapped[str] = mapped_column(String(30), default="preregistered")

    owner: Mapped[User | None] = relationship(back_populates="documents")
    loss_declarations: Mapped[list["LossDeclaration"]] = relationship(back_populates="document")


class LossDeclaration(Base, TimestampMixin):
    __tablename__ = "loss_declarations"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    number: Mapped[int] = mapped_column(Integer, index=True)
    owner_id: Mapped[str] = mapped_column(String(32), ForeignKey("users.id"), index=True)
    document_id: Mapped[str | None] = mapped_column(
        String(32), ForeignKey("documents.id"), nullable=True
    )
    doc_type: Mapped[str] = mapped_column(String(60))
    loss_date: Mapped[datetime] = mapped_column(UTCDateTime, default=utcnow)
    description: Mapped[str] = mapped_column(Text, default="")
    location: Mapped[str] = mapped_column(String(200), default="")
    owner_name: Mapped[str] = mapped_column(String(200), default="")
    fingerprint: Mapped[str] = mapped_column(Text, default="")
    status: Mapped[str] = mapped_column(String(30), default="inactive")
    reward_amount: Mapped[float] = mapped_column(Float, default=0.0)
    reward_status: Mapped[str] = mapped_column(String(30), default="none")
    escrow_reference: Mapped[str] = mapped_column(String(64), default="")
    matched_find_id: Mapped[str | None] = mapped_column(String(32), nullable=True)
    returned_at: Mapped[datetime | None] = mapped_column(UTCDateTime, nullable=True)

    document: Mapped[Document | None] = relationship(back_populates="loss_declarations")
    owner: Mapped[User | None] = relationship()
    matches: Mapped[list["MatchRecord"]] = relationship(back_populates="loss")


class FindDeclaration(Base, TimestampMixin):
    __tablename__ = "find_declarations"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    number: Mapped[int] = mapped_column(Integer, index=True)
    finder_id: Mapped[str] = mapped_column(String(32), ForeignKey("users.id"), index=True)
    document_id: Mapped[str | None] = mapped_column(
        String(32), ForeignKey("documents.id"), nullable=True
    )
    doc_type: Mapped[str] = mapped_column(String(60))
    found_date: Mapped[datetime] = mapped_column(UTCDateTime, default=utcnow)
    description: Mapped[str] = mapped_column(Text, default="")
    location: Mapped[str] = mapped_column(String(200), default="")
    holder_name: Mapped[str] = mapped_column(String(200), default="")
    source: Mapped[str] = mapped_column(String(20), default="manual")
    qr_payload: Mapped[str] = mapped_column(Text, default="")
    image_file: Mapped[str] = mapped_column(String(500), default="")
    blurred_file: Mapped[str] = mapped_column(String(500), default="")
    fingerprint: Mapped[str] = mapped_column(Text, default="")
    status: Mapped[str] = mapped_column(String(30), default="found")
    matched_owner_id: Mapped[str | None] = mapped_column(String(32), nullable=True)
    returned_at: Mapped[datetime | None] = mapped_column(UTCDateTime, nullable=True)

    finder: Mapped[User | None] = relationship()
    document: Mapped[Document | None] = relationship()
    matches: Mapped[list["MatchRecord"]] = relationship(back_populates="find")


class MatchRecord(Base, TimestampMixin):
    __tablename__ = "match_records"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    loss_id: Mapped[str] = mapped_column(String(32), ForeignKey("loss_declarations.id"), index=True)
    find_id: Mapped[str] = mapped_column(String(32), ForeignKey("find_declarations.id"), index=True)
    score: Mapped[float] = mapped_column(Float, default=0.0)
    engine: Mapped[str] = mapped_column(String(30), default="local")
    reason: Mapped[str] = mapped_column(Text, default="")
    status: Mapped[str] = mapped_column(String(30), default="proposed")

    loss: Mapped[LossDeclaration | None] = relationship(back_populates="matches")
    find: Mapped[FindDeclaration | None] = relationship(back_populates="matches")


class Transaction(Base, TimestampMixin):
    __tablename__ = "transactions"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    reference: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    kind: Mapped[str] = mapped_column(String(30))
    provider: Mapped[str] = mapped_column(String(20), default="ORANGE_MONEY")
    amount: Mapped[float] = mapped_column(Float, default=0.0)
    commission: Mapped[float] = mapped_column(Float, default=0.0)
    payer_id: Mapped[str | None] = mapped_column(String(32), nullable=True)
    payee_id: Mapped[str | None] = mapped_column(String(32), nullable=True)
    loss_id: Mapped[str | None] = mapped_column(String(32), nullable=True)
    phone: Mapped[str] = mapped_column(String(40), default="")
    pin_hash: Mapped[str] = mapped_column(String(255), default="")
    status: Mapped[str] = mapped_column(String(30), default="pending")
    message: Mapped[str] = mapped_column(String(300), default="")
    settled_at: Mapped[datetime | None] = mapped_column(UTCDateTime, nullable=True)


class Conversation(Base, TimestampMixin):
    __tablename__ = "conversations"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    owner_id: Mapped[str] = mapped_column(String(32), ForeignKey("users.id"), index=True)
    finder_id: Mapped[str] = mapped_column(String(32), ForeignKey("users.id"), index=True)
    loss_id: Mapped[str | None] = mapped_column(String(32), nullable=True)
    find_id: Mapped[str | None] = mapped_column(String(32), nullable=True)
    subject: Mapped[str] = mapped_column(String(200), default="")

    messages: Mapped[list["Message"]] = relationship(
        back_populates="conversation", cascade="all, delete-orphan"
    )


class Message(Base, TimestampMixin):
    __tablename__ = "messages"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    conversation_id: Mapped[str] = mapped_column(
        String(32), ForeignKey("conversations.id"), index=True
    )
    sender_id: Mapped[str] = mapped_column(String(32), ForeignKey("users.id"), index=True)
    body: Mapped[str] = mapped_column(Text, default="")
    read: Mapped[bool] = mapped_column(Boolean, default=False)

    conversation: Mapped[Conversation | None] = relationship(back_populates="messages")


class Notification(Base, TimestampMixin):
    __tablename__ = "notifications"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(String(32), ForeignKey("users.id"), index=True)
    title: Mapped[str] = mapped_column(String(200))
    body: Mapped[str] = mapped_column(Text, default="")
    kind: Mapped[str] = mapped_column(String(30), default="info")
    read: Mapped[bool] = mapped_column(Boolean, default=False)

    user: Mapped[User | None] = relationship(back_populates="notifications")


class Rating(Base, TimestampMixin):
    __tablename__ = "ratings"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(String(32), ForeignKey("users.id"), index=True)
    stars: Mapped[int] = mapped_column(Integer)
    comment: Mapped[str] = mapped_column(Text, default="")


class SmsLog(Base):
    __tablename__ = "sms_logs"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    phone: Mapped[str] = mapped_column(String(40))
    body: Mapped[str] = mapped_column(Text, default="")
    provider: Mapped[str] = mapped_column(String(30), default="TEXTSOFT")
    status: Mapped[str] = mapped_column(String(30), default="simulated")
    created_at: Mapped[datetime] = mapped_column(UTCDateTime, default=utcnow)


class MailLog(Base):
    __tablename__ = "mail_logs"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    email: Mapped[str] = mapped_column(String(255), index=True)
    subject: Mapped[str] = mapped_column(String(255), default="")
    body: Mapped[str] = mapped_column(Text, default="")
    status: Mapped[str] = mapped_column(String(30), default="simulated")
    created_at: Mapped[datetime] = mapped_column(UTCDateTime, default=utcnow)
