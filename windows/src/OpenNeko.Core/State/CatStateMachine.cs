namespace OpenNeko.Core;

public enum CatInput { TypingStarted, TypingStopped, HoverBegan, HoverEnded, Clicked, DragBegan, DragEnded, IdleTimeout }

/// <summary>Mirrors CatStateMachine.swift.</summary>
public sealed class CatStateMachine
{
    public CatState Current { get; private set; } = CatState.Idle;

    public void Handle(CatInput input)
    {
        // While dragging, ignore everything except the end of the drag.
        if (Current == CatState.Dragging)
        {
            if (input == CatInput.DragEnded) Current = CatState.Idle;
            return;
        }
        Current = input switch
        {
            CatInput.TypingStarted => CatState.Typing,
            CatInput.TypingStopped => CatState.Idle,
            CatInput.HoverBegan => CatState.Hover,
            CatInput.HoverEnded => CatState.Idle,
            CatInput.Clicked => CatState.Click,
            CatInput.DragBegan => CatState.Dragging,
            CatInput.DragEnded => CatState.Idle,
            CatInput.IdleTimeout => CatState.Nap,
            _ => Current,
        };
    }
}
